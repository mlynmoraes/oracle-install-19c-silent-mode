# Instalação do Oracle Database 19c em Silent Mode no Oracle Linux 8

Projeto de laboratório para praticar a preparação de um servidor Linux e instalar o Oracle Database 19c **inteiramente por linha de comando** (modo silencioso), aplicando boas práticas de sistema operacional e de organização do armazenamento.

> Este é um ambiente de estudo e não deve ser usado em produção.

---

## Objetivo

- Preparar o sistema operacional conforme os pré-requisitos do Oracle.
- Instalar os binários do Oracle Database 19c sem interface gráfica (`runInstaller -silent`).
- Criar o listener e o banco de dados (`netca` e `dbca` em modo silencioso).
- Separar binários, datafiles e área de recuperação em diretórios distintos.
- Documentar os erros encontrados e como foram resolvidos.

## Ambiente

|          Item            |                            Valor                             |
|--------------------------|--------------------------------------------------------------|
|    Virtualização         |                      VMware Workstation                      |
|    Sistema operacional   |              Oracle Linux Server 8.10 (perfil Server)        |
|    CPU / Memória         |                     2 CPUs / 8 GB de RAM                     |
|         Disco            |               1 disco de 80 GB (arquivo único)               |
|          Rede            |                             NAT                              |
|        Hostname          |                  `ora-db-lab.localdomain`                    |
|    Banco de dados        | Oracle Database 19c (arquivo `LINUX.X64_193000_db_home.zip`) |
|         Acesso           |   SSH a partir do Windows (Windows Terminal / PowerShell)    |

## Estrutura de diretórios do banco

|                Diretório                   |                Finalidade                  |
|--------------------------------------------|--------------------------------------------|
|          `/u01/app/oracle`                 |   `ORACLE_BASE` (binários e diagnósticos)  |
| `/u01/app/oracle/product/19.0.0/dbhome_1`  |               `ORACLE_HOME`                |
|          `/u01/app/oraInventory`           |       Inventário central do Oracle         |
|          `/u02/oradata`                    |   Datafiles, control files e redo logs     |
|        `/u03/fast_recovery_area`           | Fast Recovery Area (backups e arquivos de recuperação) |



## Estrutura sugerida do repositório  (VALIDAR SE ESTÁ ASSIM!)

```
oracle-19c-silent-install/
├── README.md
├── prints/
│   ├── 01-preparacao-so/
│   ├── 02-instalacao-binarios/
│   ├── 03-listener/
│   ├── 04-criacao-banco/
│   └── 05-validacao/
└── scripts/
    ├── db_install_19c.rsp
    └── criar_banco.sh
```

## Sumário

1. [Parte 1 - Preparação do sistema operacional](#parte-1---preparação-do-sistema-operacional)
2. [Parte 2 - Instalação dos binários (silent mode)](#parte-2---instalação-dos-binários-silent-mode)
3. [Parte 3 - Criação do listener](#parte-3---criação-do-listener)
4. [Parte 4 - Criação do banco de dados](#parte-4---criação-do-banco-de-dados)
5. [Parte 5 - Validação](#parte-5---validação)

---

## Parte 1 - Preparação do sistema operacional

Todos os comandos desta parte foram executados como **root**, exceto onde indicado.

### 1.1 Atualizar o sistema

```bash
dnf update -y
```

### 1.2 Instalar o pacote de pré-instalação do Oracle

O pacote `oracle-database-preinstall-19c` automatiza boa parte dos pré-requisitos, criando o usuário `oracle` e os grupos necessários (`oinstall`, `dba`, `oper`, `backupdba`, `dgdba`, `kmdba`, `racdba`) e ajustando os parâmetros de kernel e limites de recursos e instala dependências.

```bash
dnf install -y oracle-database-preinstall-19c
```

Definir a senha do usuário `oracle`:

```bash
passwd oracle
```

### 1.3 Criar os diretórios do banco

```bash
mkdir -p /u01/app/oracle/product/19.0.0/dbhome_1
mkdir -p /u02/oradata
mkdir -p /u03/fast_recovery_area

chown -R oracle:oinstall /u01 /u02 /u03
chmod -R 775 /u01 /u02 /u03
```

### 1.4 Configurar o ambiente do usuário oracle

Trocar para o usuário `oracle` e editar o perfil:

```bash
su - oracle
nano ~/.bash_profile
```

Adicionar ao final do arquivo:

```bash
# Oracle Environment Variables
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=$ORACLE_BASE/product/19.0.0/dbhome_1
export ORACLE_SID=ORCL
export PATH=$PATH:$HOME/.local/bin:$HOME/bin:$ORACLE_HOME/bin
export NLS_LANG=AMERICAN_AMERICA.AL32UTF8
```

Aplicar as variáveis na sessão atual e conferir:

```bash
source ~/.bash_profile
echo $ORACLE_HOME
```

---

## Parte 2 - Instalação dos binários (silent mode)

Aqui os binários do Oracle Database 19c são instalados **sem criar o banco** (pois será feito na Parte 4). Os comandos são executados como usuário `oracle`, exceto onde indicado.

### 2.1 Copiar o instalador para o servidor

O arquivo `LINUX.X64_193000_db_home.zip` foi baixado no Windows e disponibilizado para a VM por uma pasta compartilhada do VMware (montada em `/mnt/hgfs`). Como o 19c é distribuído como *gold image*, o zip é extraído **diretamente dentro do `ORACLE_HOME`**.

```bash
# como root 
cp /mnt/hgfs/<PASTA_COMPARTILHADA>/LINUX.X64_193000_db_home.zip /u01/app/oracle/product/19.0.0/dbhome_1/
chown oracle:oinstall /u01/app/oracle/product/19.0.0/dbhome_1/LINUX.X64_193000_db_home.zip
```

### 2.2 Extrair os arquivos

```bash
su - oracle
cd $ORACLE_HOME
unzip LINUX.X64_193000_db_home.zip
```

### 2.3 Preparar o response file

O instalador em modo silencioso lê todas as opções de um *response file*. Em vez de editar o arquivo original, fazemos uma cópia na home do usuário, o que também permite versioná-la no repositório (`scripts/db_install_19c.rsp`):

```bash
cp $ORACLE_HOME/install/response/db_install.rsp ~/db_install_19c.rsp
nano ~/db_install_19c.rsp
```

Parâmetros que precisam ser preenchidos (os demais permanecem como estão):

|                  Parâmetro             |                  Valor                    |
|----------------------------------------|-------------------------------------------|
|          `oracle.install.option`       |           `INSTALL_DB_SWONLY`             |
|             `UNIX_GROUP_NAME`          |               `oinstall`                  |
|           `INVENTORY_LOCATION`         |         `/u01/app/oraInventory`           |
|              `ORACLE_HOME`             |  `/u01/app/oracle/product/19.0.0/dbhome_1`|
|              `ORACLE_BASE`             |           `/u01/app/oracle`               |
|    `oracle.install.db.InstallEdition`  |                  `EE`                     |
|    `oracle.install.db.OSDBA_GROUP`     |                 `dba`                     |
|    `oracle.install.db.OSOPER_GROUP`    |                 `oper`                    |
|  `oracle.install.db.OSBACKUPDBA_GROUP` |              `backupdba`                  |
|    `oracle.install.db.OSDGDBA_GROUP`   |                `dgdba`                    |
|    `oracle.install.db.OSKMDBA_GROUP`   |                `kmdba`                    |
|    `oracle.install.db.OSRACDBA_GROUP`  |               `racdba`                    |


Conferir os valores preenchidos:

```bash
grep -E '^(oracle.install.option|UNIX_GROUP_NAME|INVENTORY_LOCATION|ORACLE_HOME|ORACLE_BASE|oracle.install.db.InstallEdition|oracle.install.db.OS)' ~/db_install_19c.rsp
```

> **Atenção:** o valor de `ORACLE_HOME` no arquivo precisa ser **idêntico** ao diretório de onde o instalador é executado. Uma letra errada causa o erro `INS-35954`.

### 2.4 Executar o instalador

O Oracle Linux 8 não é reconhecido pelo instalador do 19c base (19.3). Para contornar essa verificação, define-se a variável `CV_ASSUME_DISTID` antes de executar:

```bash
export CV_ASSUME_DISTID=OEL7.8
cd $ORACLE_HOME
./runInstaller -silent -ignorePrereqFailure -responseFile ~/db_install_19c.rsp
```

|         Opção          |                Função               |
|------------------------|-------------------------------------|
|       `-silent`        | Executa sem interface gráfica       |
| `-ignorePrereqFailure` | Não interrompe por falhas de pré-requisito (aceitável em laboratório; os avisos devem ser lidos no log) |
|     `-responseFile`    | Arquivo com as opções de instalação |

Resultado esperado ao final: a mensagem `Successfully Setup Software`. O aviso `INS-32047` (inventário "não está vazio") é inofensivo neste caso, pois o diretório já existia.

### 2.5 Executar os scripts de root

Ao final, o instalador pede que dois scripts sejam executados como **root**, nesta ordem:

```bash
/u01/app/oraInventory/orainstRoot.sh
/u01/app/oracle/product/19.0.0/dbhome_1/root.sh
```

---

## Parte 3 - Criação do listener

O listener é o processo que recebe as conexões de rede e as encaminha para o banco. Ele é criado antes do banco para que o `dbca` já possa registrar os serviços nele. Os comandos são executados como usuário `oracle`.

### 3.1 Criar e iniciar o listener

```bash
su - oracle
netca -silent -responseFile $ORACLE_HOME/assistants/netca/netca.rsp
```

O `netca` em modo silencioso usa o response file padrão, que cria um listener chamado `LISTENER` na porta `1521` (TCP) e o inicia. Resultado esperado ao final:

```
Listener iniciado com sucesso.
Configuração do Oracle Net Services bem-sucedida. O código de saída é 0
```

### 3.2 Verificar o status

```bash
lsnrctl status
```

Pontos a conferir na saída:

|          Item         |                Valor esperado               |
|-----------------------|---------------------------------------------|
|         Alias         |                  `LISTENER`                 |
|     Endpoint TCP      |  `HOST=ora-db-lab.localdomain`, `PORT=1521` |
| Arquivo de parâmetros |  `$ORACLE_HOME/network/admin/listener.ora`  |

> **Observação:** neste momento a saída mostra `The listener supports no services`. Isso é normal, pois o banco ainda não foi criado. Após a Parte 4, os serviços `ORCL` e `PDB1` passam a aparecer.

---

## Parte 4 - Criação do banco de dados

O banco é criado com o `dbca` (Database Configuration Assistant) em modo silencioso. É nesta etapa que a separação de armazenamento definida na Parte 1 entra em uso: datafiles em `/u02/oradata` e Fast Recovery Area em `/u03/fast_recovery_area`.
Os comandos são executados como usuário `oracle`.

### 4.1 Verificações antes de criar

```bash
whoami                      # deve retornar: oracle
echo $ORACLE_HOME $ORACLE_SID
df -h /u01 /u02 /u03        # espaço livre (recomendado: pelo menos 30 GB livres no total)
free -m                     # memória disponível
lsnrctl status              # listener ativo
```

### 4.2 Script de criação

O comando foi salvo em `scripts/criar_banco.sh` para ficar reproduzível:

```bash
#!/bin/bash
dbca -silent -createDatabase \
  -templateName General_Purpose.dbc \
  -gdbname ORCL -sid ORCL \
  -responseFile NO_VALUE \
  -characterSet AL32UTF8 \
  -sysPassword <SUA_SENHA> \
  -systemPassword <SUA_SENHA> \
  -createAsContainerDatabase true \
  -numberOfPDBs 1 -pdbName PDB1 -pdbAdminPassword <SUA_SENHA> \
  -databaseType MULTIPURPOSE \
  -memoryMgmtType auto_sga -totalMemory 3072 \
  -storageType FS \
  -datafileDestination /u02/oradata \
  -recoveryAreaDestination /u03/fast_recovery_area \
  -recoveryAreaSize 20480 \
  -redoLogFileSize 100 \
  -emConfiguration NONE
```

### 4.3 O que cada parâmetro faz

| Parâmetro | Valor | Explicação |
|---|---|---|
| `-silent -createDatabase` | | Cria o banco sem interface gráfica |
| `-templateName` | `General_Purpose.dbc` | Modelo de banco de uso geral |
| `-gdbname` / `-sid` | `ORCL` | Nome global do banco e identificador da instância |
| `-responseFile` | `NO_VALUE` | Indica que as opções vêm da linha de comando, e não de um arquivo |
| `-characterSet` | `AL32UTF8` | Conjunto de caracteres Unicode, o recomendado atualmente |
| `-sysPassword` / `-systemPassword` | `<SUA_SENHA>` | Senhas dos usuários administrativos `SYS` e `SYSTEM` |
| `-createAsContainerDatabase` | `true` | Cria um banco multitenant (CDB), a arquitetura padrão do 19c |
| `-numberOfPDBs` / `-pdbName` | `1` / `PDB1` | Cria um banco plugável (PDB) dentro do CDB |
| `-pdbAdminPassword` | `<SUA_SENHA>` | Senha do administrador do PDB |
| `-databaseType` | `MULTIPURPOSE` | Perfil de uso geral (mistura de leitura e escrita) |
| `-memoryMgmtType` / `-totalMemory` | `auto_sga` / `3072` | Gerenciamento automático da SGA; 3072 MB (3 GB) dos 8 GB da VM, deixando folga para o sistema operacional |
| `-storageType` | `FS` | Armazenamento em sistema de arquivos (file system) |
| `-datafileDestination` | `/u02/oradata` | Local dos datafiles, control files e redo logs |
| `-recoveryAreaDestination` | `/u03/fast_recovery_area` | Local da Fast Recovery Area (FRA) |
| `-recoveryAreaSize` | `20480` | Tamanho máximo da FRA em MB (20 GB) |
| `-redoLogFileSize` | `100` | Tamanho de cada redo log em MB |
| `-emConfiguration` | `NONE` | Não configura o Enterprise Manager Express |

### 4.4 Executar

```bash
chmod +x criar_banco.sh
./criar_banco.sh
```

O processo leva alguns minutos e mostra o andamento em etapas, de 1% a 100%:

```
Preparar para operação de bd
Copiando arquivos de banco de dados
Criando e iniciando a instância Oracle
Concluindo Criação de Banco de Dados
Criando Bancos de Dados Plugáveis
Executando Ações Pós-configuração
100% concluído
Criação do banco de dados concluída.
```

Os logs da criação ficam em `/u01/app/oracle/cfgtoollogs/dbca/ORCL/`.

---

## Parte 5 - Validação

Com o banco criado, validamos se a instância, os PDBs, os datafiles e a Fast Recovery Area estão como planejado. Os comandos são executados como usuário `oracle`.

### 5.1 Listener com os serviços registrados

```bash
lsnrctl status
```

Diferente da Parte 3, agora o listener lista os serviços do banco, todos com a instância `ORCL` em status `READY`:

|    Serviço   |             Descrição          |
|--------------|--------------------------------|
|     `ORCL`   |          Serviço do CDB        |
|   `ORCLXDB`  | Serviço do XML DB (dispatcher) |
|     `pdb1`   | Serviço do banco plugável PDB1 |
| Serviço com nome hexadecimal (GUID) | Serviço criado automaticamente para o PDB1 |


### 5.2 Conectar e ajustar a formatação

```bash
sqlplus / as sysdba
```

```sql
SET LINESIZE 200
SET PAGESIZE 100
COL name FORMAT A60
COL open_mode FORMAT A12
```

### 5.3 Banco e PDBs

```sql
SHOW CON_NAME;
SELECT name, open_mode, cdb FROM v$database;
SELECT name, open_mode FROM v$pdbs;
```

|      Verificação     |      Resultado esperado      |
|----------------------|------------------------------|
|      `CON_NAME`      |          `CDB$ROOT`          |
|      Banco `ORCL`    |    `READ WRITE`, `CDB = YES` |
|      `PDB$SEED`      |          `READ ONLY`         |
|        `PDB1`        |         `READ WRITE`         |

### 5.4 Localização dos datafiles

```sql
SELECT name FROM v$datafile;
```

Resultado: 11 arquivos, todos em `/u02/oradata/ORCL/` (incluindo as subpastas `pdbseed` e `PDB1`), o que confirma a separação de armazenamento planejada.

### 5.5 Fast Recovery Area

```sql
SHOW PARAMETER db_recovery_file_dest;
```

|            Parâmetro         |             Valor          |
|------------------------------|----------------------------|
|     `db_recovery_file_dest`  |  `/u03/fast_recovery_area` |
| `db_recovery_file_dest_size` |            `20G`           |

### 5.6 Salvar o estado do PDB1

Por padrão, após reiniciar o CDB, os PDBs voltam ao estado `MOUNTED`. Para que o `PDB1` abra automaticamente junto com o CDB, o estado é salvo (executado em `CDB$ROOT`):

```sql
ALTER PLUGGABLE DATABASE PDB1 SAVE STATE;
SELECT con_name, state FROM dba_pdb_saved_states;
```

Resultado esperado: `PDB1` com o estado `OPEN`.

---


## Referências

- Documentação oficial do Oracle Database 19c: *Database Installation Guide for Linux*
- Oracle Linux 8: pacote `oracle-database-preinstall-19c`

---

*Projeto de estudo realizado em ambiente de laboratório. Nenhum dado ou servidor de produção foi utilizado.*
