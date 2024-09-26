#!/bin/bash
# Script for generating a master address and fund it with test ADA 

# Exit script if any command returns a non zero number 
set -e

# Input parameter
testnet=$1

if [ $testnet = "preprod" ]; then
    testnet_number=1
elif [ $testnet = "preview" ]; then
    testnet_number=2
else
    echo "Testnet parameter can only be preview or preprod."
    exit 1
fi

# Creating verification and signing keys 
master_skey="master.skey"
master_vkey="master.vkey"

if [[ ! -e "$master_vkey" ]]; then 
    echo "Creating master address keys"
    cardano-cli address key-gen \
        --signing-key-file "$master_skey" \
        --verification-key-file "$master_vkey"
else 
  echo "Master address verification key already present."
fi

# Generating master address 
echo "Generating master address." 
master_address=$(cardano-cli address build \
                    --testnet-magic "$testnet_number" \
                    --payment-verification-key-file "$master_vkey")
echo "Master address is: $master_address"
echo $master_address > master.addr 

# Request funds from the Faucet 
echo "Requesting funds for master address from the Cardano faucet." 
if [ $testnet_number -eq 1 ]; then 
    curl -X POST -s 'https://faucet.preprod.world.dev.cardano.org/send-money/'$master_address'?api_key=ooseiteiquo7Wie9oochooyiequi4ooc' > /dev/null
elif [ $testnet_number -eq 2 ]; then 
    curl -X POST -s 'https://faucet.preview.world.dev.cardano.org/send-money/'$master_address'?api_key=nohnuXahthoghaeNoht9Aow3ze4quohc' > /dev/null
fi 

# Check if funds arrive at master address within 3 minutes 
funds_arrived=false
for i in $(seq 1 60); do 
    master_addr_funds=$(cardano-cli query utxo \
                          --address $master_address \
                          --testnet-magic $testnet_number)
    sleep 3
    if [[ "$master_addr_funds" == *"lovelace"* ]]; then 
        funds_arrived=true
        echo "Funds at master address received."
        break
    fi  
done

if [ $funds_arrived = false ]; then
    echo "Funds at master wallet not received within a minute. Exiting script." 
    exit 1
fi

