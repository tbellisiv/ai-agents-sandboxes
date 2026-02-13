#!/bin/bash

SCRIPT_DIR=$(dirname $0)
SCRIPT_NAME=$(basename $0)

success=0  #true

dotnet tool install -g dotnet-reportgenerator-globaltool
if [ $? -ne 0 ]; then
  success=1
fi

dotnet tool install -g coverlet.console
if [ $? -ne 0 ]; then
  success=1
fi

dotnet tool install --global dotnet-coverage
if [ $? -ne 0 ]; then
  success=1
fi

dotnet tool install -g roslynator.dotnet.cli
if [ $? -ne 0 ]; then
  success=1
fi

echo ""
if [ "$success" = "0" ]; then
  echo "$SCRIPT_NAME: dotnet tool init failed"
else
  echo "$SCRIPT_NAME: dotnet tool init completed"
fi
echo ""

