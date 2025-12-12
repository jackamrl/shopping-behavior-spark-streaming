# Installation Terraform sur Windows

## Méthode 1 : Via winget (Recommandé - Windows 10/11)

```powershell
winget install HashiCorp.Terraform
```

## Méthode 2 : Téléchargement manuel

1. **Télécharger Terraform** :
   - Aller sur : https://www.terraform.io/downloads
   - Télécharger la version Windows (64-bit) : `terraform_<version>_windows_amd64.zip`

2. **Extraire et installer** :
   ```powershell
   # Créer un dossier pour Terraform (exemple)
   New-Item -ItemType Directory -Force -Path "C:\terraform"
   
   # Extraire le ZIP dans ce dossier
   # (Télécharger manuellement et extraire terraform.exe dans C:\terraform)
   
   # Ajouter au PATH
   [Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\terraform", "User")
   ```

3. **Redémarrer PowerShell** et vérifier :
   ```powershell
   terraform --version
   ```

## Méthode 3 : Via Chocolatey (si installé)

```powershell
choco install terraform
```

## Vérification

Après installation, vérifiez :

```powershell
terraform --version
```

Vous devriez voir quelque chose comme : `Terraform v1.6.x`



