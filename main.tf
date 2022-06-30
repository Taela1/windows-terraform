# In dieser Variable fragen wir nach dem API Key und Secret der im Terraform genutzt werden soll. Dadurch wird der genutzte Exoscale Account ausgewaehlt
variable "exoscale_api_key" { }
variable "exoscale_api_secret" { }

# Wir koennen ein Projektname vergeben der im Script als Variable fuer Namen genutzt wird. Damit kann man das gleiche Deployment fuer mehrere Vorgaenge nutzen.
# Es koennen z.B. Kundennamen, Bestellnummern, Rechnungsnummern etc vergeben werden damit man Instanzen eindeutig Kunden bzw. Bestellungen zuweisen kann
variable "project" { }

# Wir definieren die Zone (Exoscale Standort) der genutzt werden soll
locals {
  zone = "de-fra-1"
}

# Hier vergeben wir ein Passwort das einem User gehoert den wir spaeter mit Cloud Init auf dem Windows Server anlegen.
variable "password" {
  description = "Password for user tfuser"
  type        = string
  sensitive   = true
}

# Hier wird der Terraform provider konfiguriert. Wir definieren das wir den Provider "exoscale/exoscale" benoetigen.
terraform {
  required_providers {
    exoscale = {
      source  = "exoscale/exoscale"
    }
  }
}

# Hier uebergeben wir den als Variable abgefragten Key an Terraform damit der Provider diesen nutzen kann
provider "exoscale" {
  key    = "${var.exoscale_api_key}"
  secret = "${var.exoscale_api_secret}"
}

# Wir brauchen eine Security Gruppe um Ports in unserer Firewall oeffnen zu koennen. Wir nutzen die Projekt Variable im Namen um doppelte Namen zu vermeiden und die Verknuepfung zu dem Kunden herzustellen. Wir geben der Security Group die interne ID "sg1"
resource "exoscale_security_group" "sg1" {
  name = "${var.project}-sg1"
}

# Wir fuegen eine Regel in die vorher erstellte Security Gruppe damit wir per RDP (TCP Port 3389) auf den Server koennen. 
resource "exoscale_security_group_rule" "ms-rdp" {
  # Hier geben wir die ID der Security Groupe "sg1" an als Ziel fue dir Regel.
  security_group_id = exoscale_security_group.sg1.id
  type = "INGRESS"
  protocol = "TCP"
  start_port = "3389"
  end_port = "3389"
  cidr = "0.0.0.0/0"
}

# Wir definieren das Template das fuer den Server genutzt werden soll. Hier kann man das Betriebssystem auswaehlen. Wir geben die Zone als Variable "local.zone" durch
data "exoscale_compute_template" "windows2019" {
  zone = local.zone
  name = "Windows Server 2019"
}

# Hier erstellen wir den Windows Server. Wir uebergeben Variablen ueber die Zone, den Namen, die Security Gruppen sowie das Template (OS) das genutzt werden soll.
resource "exoscale_compute_instance" "winserver" {
  zone               = local.zone
  name               = "${var.project}-srv"
  type               = "standard.medium"
  template_id        = data.exoscale_compute_template.windows2019.id
  disk_size          = 50
  security_group_ids = [
    exoscale_security_group.sg1.id,
  ]
  # Hier geben wir die User Data weiter, es kann auf eine .ps1 verwiesen werden oder aber direkt Powershell eingepflegt werden.
  user_data          = <<EOF
#ps1
New-Item C:\Users\Administrator\Desktop\test.txt
Set-Content C:\Users\Administrator\Desktop\test.txt 'User Data worked!'
$password = ConvertTo-SecureString "${var.password}" -AsPlainText -Force 
New-LocalUser -Name "tfuser" -Password $password -FullName "Terraform User" -Description "Test user created by Terraform"
Add-LocalGroupMember -Group Administrators -Member "tfuser"
EOF
}
