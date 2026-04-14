output "public_ip" {
  description = "The public URL of the EC2 web server (Apache + PHP 8.2)"
  value       = "http://${aws_instance.web_server.public_ip}/"
}

output "api_url" {
  value = aws_apigatewayv2_api.api.api_endpoint
}