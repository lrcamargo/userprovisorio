<#
.SYNOPSIS
    Script de automação para configuração de usuários, domínio e rede.
#>

# --- CONFIGURAÇÕES MANUAIS ---
$DnsPrimario = "8.8.8.8"
$DnsSecundario = "8.8.4.4"
$CaminhoCSV = "C:\users.csv" 
$WorkgroupName = "SESISENAIPA"

# --- FUNÇÕES ---

function Criar-UsuarioLocal {
    param ($username, $password, $group)

    if ([string]::IsNullOrWhiteSpace($username)) { return }

    # Tenta localizar o usuário no sistema
    $existe = net user "$username" 2>$null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Criando usuário: $username" -ForegroundColor Cyan
        
        # Comando direto para criação
        & net user "$username" "$password" /add /y /expires:never 2>&1 | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            & net localgroup "$group" "$username" /add 2>&1 | Out-Null
            Write-Host "Sucesso: $username criado." -ForegroundColor Green
        } else {
            Write-Host "Erro: Falha ao criar $username (verifique a senha)." -ForegroundColor Red
        }
    } else {
        Write-Host "Aviso: $username já existe." -ForegroundColor Yellow
    }
}

function Ajustar-DNS {
    Write-Host "Ajustando DNS..." -ForegroundColor Cyan
    $nics = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }
    foreach ($nic in $nics) {
        $nic.SetDNSServerSearchOrder(@($DnsPrimario, $DnsSecundario))
    }
}

function Sair-Dominio {
    $sysInfo = Get-WmiObject Win32_ComputerSystem
    if ($sysInfo.PartOfDomain) {
        Write-Host "Saindo do domínio..." -ForegroundColor Magenta
        $sysInfo.UnjoinDomainOrWorkgroup($null, $null, 0)
    }
}

# --- EXECUÇÃO ---

# Garante que é Admin
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "ERRO: EXECUTE COMO ADMINISTRADOR!" -ForegroundColor Red
    return
}

$tipo = Read-Host "A máquina é de DOCENTE? (S/N)"

if ($tipo.ToUpper() -eq "S") {
    if (Test-Path $CaminhoCSV) {
        # Importa o CSV (testa vírgula e ponto-e-vírgula automaticamente)
        $dados = Import-Csv $CaminhoCSV -Delimiter ","
        if ($null -eq $dados.usuario[0]) { $dados = Import-Csv $CaminhoCSV -Delimiter ";" }

        foreach ($linha in $dados) {
            # Pega exatamente o que está na coluna 'usuario'
            $nome = $linha.usuario
            $pass = $linha.senha
            
            Criar-UsuarioLocal -username $nome -password $pass -group "Usuários"
        }
    } else {
        Write-Host "Arquivo não encontrado em $CaminhoCSV" -ForegroundColor Red
    }
} else {
    Criar-UsuarioLocal "suporte" "usrSupP@19" "Administradores"
    Criar-UsuarioLocal "aluno" "laboratorio" "Usuários"
}

Sair-Dominio
Ajustar-DNS

Write-Host "Finalizado!" -ForegroundColor Green