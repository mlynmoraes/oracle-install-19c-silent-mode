#!/bin/bash
dbca -silent -createDatabase \
  -templateName General_Purpose.dbc \
  -gdbname ORCL -sid ORCL \
  -responseFile NO_VALUE \
  -characterSet AL32UTF8 \
  -sysPassword emyoracle \
  -systemPassword emyoracle \
  -createAsContainerDatabase true \
  -numberOfPDBs 1 -pdbName PDB1 -pdbAdminPassword emyoracle \
  -databaseType MULTIPURPOSE \
  -memoryMgmtType auto_sga -totalMemory 3072 \
  -storageType FS \
  -datafileDestination /u02/oradata \
  -recoveryAreaDestination /u03/fast_recovery_area \
  -recoveryAreaSize 20480 \
  -redoLogFileSize 100 \
  -emConfiguration NONE