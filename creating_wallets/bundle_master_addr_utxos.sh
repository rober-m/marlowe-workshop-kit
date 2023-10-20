
#!/bin/bash

# Script that bundles UTXOs from the master address into one UTXO  

# Exit script in case of error 
set -e 

# Input parameters to the script
testnet=$1

# Setting the testnet number 
if [ $testnet = "preprod" ]; then
    testnet_number=1
elif [ $testnet = "preview" ]; then
    testnet_number=2
else
    echo "Testnet parameter can only be preview or preprod."
    exit 1
fi

# Master address and signing keys
master_skey="master.skey"
master_address=$(cat master.addr)

# Read the UTXOs from the master address 
cardano-cli query utxo  \
    --address $master_address \
    --testnet-magic $testnet_number \
    --out-file master_address_funds.txt 

master_address_utxos=($(cat master_address_funds.txt | jq -r 'keys')) 
master_address_first_utxos=$(cat master_address_funds.txt | jq -r 'keys[0]')

# Create the build transaction command 
transaction_build_part1="cardano-cli transaction build 
                            --babbage-era 
                            --testnet-magic $testnet_number "

transaction_build_part3="--change-address $master_address 
                         --out-file tx.body" 

tx_in_part=""
last_index=$((${#master_address_utxos[@]}-1))
for i in $(seq 0 $last_index);
do
    unprocessed_utxo=${master_address_utxos[$i]}
    if [[ $i -ne  0 ]] && [[ $i -ne $last_index ]]; then
        utxo_without_comma=(${unprocessed_utxo//,/ })
        clean_utxo=(${utxo_without_comma//\"/ })
        tx_in_part+="--tx-in $clean_utxo "
    fi
done

transaction_build="$transaction_build_part1$tx_in_part$transaction_build_part3"

# Execute the build, sing and submit transaction commands 
$transaction_build

cardano-cli transaction sign  \
    --tx-body-file tx.body  \
    --signing-key-file $master_skey  \
    --testnet-magic $testnet_number  \
    --out-file tx.signed 

cardano-cli transaction submit  \
    --testnet-magic $testnet_number  \
    --tx-file tx.signed 

echo "Submitted transaction." 

# Checking if UTXOs at master address were updated  
master_addr_funds_updated=false
for i in $(seq 1 15); 
do
    sleep 4
    cardano-cli query utxo  \
        --address $master_address \
        --testnet-magic $testnet_number \
        --out-file master_address_funds.txt \
    >> transaction.log 2>&1

    master_address_first_utxo_current=$(cat master_address_funds.txt | jq -r 'keys[0]')

    if [ $master_address_first_utxos != $master_address_first_utxo_current ]; then
        master_addr_funds_updated=true
        break
    fi
done

if [ $master_addr_funds_updated = false ]; then
    echo "Funds at master wallet not updated within a minute. Exiting script." 
else
    echo "UTXOs at master address were updated." 
fi 
