#!/bin/bash
set -euo pipefail
export HOME=/root
export COMPOSER_HOME=/root/.composer
dnf update -y
dnf install -y httpd php8.2 php8.2-cli php8.2-common php8.2-fpm php8.2-mysqlnd php8.2-pdo php8.2-intl mariadb114 git aws-cli ruby wget

# DB credentials (SQL import + .env)
DB_SECRET=$(aws secretsmanager get-secret-value \
  --secret-id "${db_secret_name}" \
  --query "SecretString" \
  --output text)

DB_USERNAME=$(echo "$DB_SECRET" | python3 -c "import sys,json; print(json.load(sys.stdin)['username'])")
DB_PASSWORD=$(echo "$DB_SECRET" | python3 -c "import sys,json; print(json.load(sys.stdin)['password'])")

# Download and import the SQL file from S3
aws s3 cp s3://homelink-demo-sql-bucket/homelink_demo.sql /tmp/homelink_demo.sql
mysql -h "${db_host}" -u "$DB_USERNAME" -p"$DB_PASSWORD" --ssl=false < /tmp/homelink_demo.sql
rm -f /tmp/homelink_demo.sql

# GitHub deploy token (SecretString JSON: {"token":"..."})
GITHUB_TOKEN=$(aws secretsmanager get-secret-value \
  --secret-id "${github_token_secret_name}" \
  --query "SecretString" \
  --output text | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")

rm -rf /var/www/html
git clone "https://x-access-token:$GITHUB_TOKEN@github.com/ianzammit-devops/homelink-demo.git" /var/www/html

unset GITHUB_TOKEN

cp /var/www/html/env-example /var/www/html/.env

IMDS_TOKEN=$(curl -sSf -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
PUBLIC_IP=$(curl -sSf -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)

sed -i "s|REPLACE_ENVIRONMENT|production|g"           /var/www/html/.env
sed -i "s|^app\.baseURL\s*=.*|app.baseURL = 'http://$PUBLIC_IP/'|" /var/www/html/.env
sed -i "s|REPLACE_DATABASE_HOSTNAME|${db_host}|g"     /var/www/html/.env
sed -i "s|REPLACE_DATABASE_NAME|${db_name}|g"          /var/www/html/.env
sed -i "s|REPLACE_DATABASE_USERNAME|$DB_USERNAME|g"   /var/www/html/.env

# Use Python for password substitution to safely handle special characters
python3 -c "
import re
with open('/var/www/html/.env', 'r') as f:
    content = f.read()
content = content.replace('REPLACE_DATABASE_PASSWORD', '$DB_PASSWORD')
with open('/var/www/html/.env', 'w') as f:
    f.write(content)
"

sed -i "s|REPLACE_LOGGER_THRESHOLD|1|g"              /var/www/html/.env

unset DB_USERNAME DB_PASSWORD DB_SECRET

# Install Composer
php -r "copy('https://getcomposer.org/installer', '/tmp/composer-setup.php');"
php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer
rm -f /tmp/composer-setup.php

# Trust the /var/www/html directory for git (needed by Composer)
git config --global --add safe.directory /var/www/html

# Install PHP dependencies
cd /var/www/html
composer install --no-dev --optimize-autoloader --no-interaction

chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html
chmod 640 /var/www/html/.env

cat > /etc/httpd/conf.d/php-fpm.conf << 'EOF'
<Directory /var/www/html>
    AllowOverride All
    Require all granted
</Directory>

<FilesMatch \.php$>
    SetHandler "proxy:unix:/run/php-fpm/www.sock|fcgi://localhost"
</FilesMatch>
DirectoryIndex index.php index.html
EOF

systemctl enable --now php-fpm
systemctl enable --now httpd

# Install CodeDeploy agent
REGION=$(curl -sSf -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" http://169.254.169.254/latest/meta-data/placement/region)
wget "https://aws-codedeploy-$REGION.s3.$REGION.amazonaws.com/latest/install" -O /tmp/codedeploy-install
chmod +x /tmp/codedeploy-install
/tmp/codedeploy-install auto
systemctl enable --now codedeploy-agent
rm -f /tmp/codedeploy-install