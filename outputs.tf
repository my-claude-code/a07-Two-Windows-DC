output "dc1_public_ip" {
  description = "RDP into DC1 (firstad.local) — initial password ClaudeCode2023!, changes to '1' after setup completes"
  value       = azurerm_public_ip.dc1.ip_address
}

output "dc2_public_ip" {
  description = "RDP into DC2 (secondad.local) — initial password ClaudeCode2023!, changes to '1' after setup completes"
  value       = azurerm_public_ip.dc2.ip_address
}
