#!/bin/bash

# Установка и настройка брандмауэра
apt install ufw -y
ufw allow ssh
ufw allow https
ufw allow http
ufw allow 9151
ufw enable

# Загрузка и распаковка Geth
wget https://gethstore.blob.core.windows.net/builds/geth-linux-amd64-1.10.23-d901d853.tar.gz
tar -xvzf geth-linux-amd64-1.10.23-d901d853.tar.gz
cd geth-linux-amd64-1.10.23-d901d853/

# Создание Ethereum аккаунта
./geth account new --keystore ./keystore

# Установка Docker
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg -y
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

# Загрузка образа NuLink
docker pull nulink/nulink:latest

# Подготовка директории для NuLink
mkdir -p /root/nulink
cp /root/geth-linux-amd64-1.10.23-d901d853/keystore/* /root/nulink
chmod -R 777 /root/nulink

# Запрос ввода данных пользователя
read -p "Введите пароль для keystore: " NULINK_KEYSTORE_PASSWORD
read -p "Введите пароль аккаунта работника: " NULINK_OPERATOR_ETH_PASSWORD
read -p "Введите адрес Ethereum аккаунта работника: " WORKER_ADDRESS

# Экспорт переменных окружения
export NULINK_KEYSTORE_PASSWORD
export NULINK_OPERATOR_ETH_PASSWORD

# Инициализация конфигурации ноды
docker run -it --rm -p 9151:9151 -v /root/nulink:/code -v /root/nulink:/home/circleci/.local/share/nulink -e NULINK_KEYSTORE_PASSWORD nulink/nulink nulink ursula init --signer keystore:///code/UTC--2023-12-31T17-42-14.316243885Z--f3defb90c2f03e904bd9662a1f16dcd1ca69b00a --eth-provider https://data-seed-prebsc-2-s2.binance.org:8545 --network horus --payment-provider https://data-seed-prebsc-2-s2.binance.org:8545 --payment-network bsc_testnet --operator-address $WORKER_ADDRESS --max-gas-price 10000000000

# Запуск ноды
docker run --restart on-failure -d --name ursula -p 9151:9151 -v /root/nulink:/code -v /root/nulink:/home/circleci/.local/share/nulink -e NULINK_KEYSTORE_PASSWORD -e NULINK_OPERATOR_ETH_PASSWORD nulink/nulink nulink ursula run --no-block-until-ready

# Проверка статуса ноды
docker logs -f ursula
