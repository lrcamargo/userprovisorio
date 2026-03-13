<#
.SYNOPSIS
    Script de automação para configuração de usuários, domínio e rede.
    Compatível com Windows 7, 10 e 11.
#>

# --- CONFIGURAÇÕES MANUAIS ---
$DnsPrimario = "8.8.8.8"  # Insira o IP desejado aqui
$DnsSecundario = "8.8.4.4" # Insira o IP desejado aqui
$CaminhoCSV = "C:\temp\usuarios.csv" # Caminho do arquivo com os usuários
$WorkgroupName = "SESISENAIPA"

# --- FUNÇÕES AUXILIARES ---

function Criar-UsuarioLocal($username, $password, $group) {
    if (!(Get-WmiObject Win32_UserAccount | Where-Object { $_.Name -eq $username })) {
        Write-Host "Criando usuário: $username..." -ForegroundColor Cyan
        net user $username $password /add /y /expires:never
        net localgroup $group $username /add
    } else {
        Write-Host "Usuário $username já existe." -ForegroundColor Yellow
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
        Write-Host "Removendo do domínio e movendo para $WorkgroupName..." -ForegroundColor Orange
        # Nota: Pode solicitar credenciais se não estiver rodando como Admin de Domínio
        $sysInfo.UnjoinDomainOrWorkgroup()
        $sysInfo.Rename($null, $null, $WorkgroupName)
        Write-Host "Reinicialização necessária para concluir a saída do domínio." -ForegroundColor Red
    }
}

# --- EXECUÇÃO PRINCIPAL ---

# Pergunta o tipo de máquina
$tipo = Read-Host "A máquina é de DOCENTE? (S/N)"

if ($tipo.ToUpper() -eq "S") {
    # FUNÇÃO 1: Criar usuários em lote via CSV
    if (Test-Path $CaminhoCSV) {
        $usuarios = Import-Csv $CaminhoCSV
        foreach ($user in $usuarios) {
            # O CSV deve ter colunas 'usuario' e 'senha'
            Criar-UsuarioLocal $user.usuario $user.senha "Usuários"
        }
    } else {
        Write-Warning "Arquivo CSV não encontrado em $CaminhoCSV"
    }
} else {
    # FUNÇÃO 2 e 3: Criar Suporte e Aluno
    Criar-UsuarioLocal "suporte" "SenhaSuporte@123" "Administradores"
    Criar-UsuarioLocal "aluno" "SenhaAluno@123" "Usuários"
}

# FUNÇÃO 4: Domínio -> Grupo de Trabalho
Sair-Dominio

# FUNÇÃO 5: Ajuste de DNS
Ajustar-DNS

Write-Host "Procedimento finalizado!" -ForegroundColor Green