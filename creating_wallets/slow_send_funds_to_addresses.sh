#!/bin/bash
# Script that sends a fixed amount of ADA to all addresses in addresses.txt from the 
# master address contained in master.addr. Sends the funds one transaction at a time.  

# Exit script in case of error 
set -e

# Input parameters 
testnet=$1
ada_amount_per_wallet=$2 

addresses_file_line_count=$(wc -l addresses.txt)
number_of_wallets=${addresses_file_line_count::1}

master_skey="master.skey"

# Some security checks 
if [ 10000 -lt $(($number_of_wallets*$ada_amount_per_wallet)) ]; then
    echo "Amount of total ADA to send exceeds 10.000 ADA." 
    exit 1
fi

# Setting the testnet number 
if [ $testnet = "preprod" ]; then
    testnet_number=1
elif [ $testnet = "preview" ]; then
    testnet_number=2
else
    echo "Testnet parameter can only be preview or preprod."
    exit 1
fi

# Reading the master address from file 
master_address=$(cat master.addr | tr -d '\n')

# Computing the master address UTXO 
cardano-cli query utxo  \
    --address $master_address \
    --testnet-magic $testnet_number \
    --out-file master_address_funds.txt \
>> transaction.log 2>&1

master_address_utxo=$(cat master_address_funds.txt | jq -r 'keys[0]')

# Sends funds to addresses. One transaction per one address. 
echo "Sending $ada_amount_per_wallet ADA to each of the $number_of_wallets addresses." 
while IFS= read -r user_address; do
    msg="Sending funds to address $user_address."
    echo $msg && echo $msg >> transaction.log

    cardano-cli transaction build  \
        --babbage-era  \
        --testnet-magic $testnet_number  \
        --tx-in $master_address_utxo  \
        --tx-out "$user_address + $((1000000*$ada_amount_per_wallet)) lovelace"  \
        --change-address $master_address  \
        --out-file tx.body  \
    >> transaction.log 2>&1

    cardano-cli transaction sign  \
        --tx-body-file tx.body  \
        --signing-key-file $master_skey  \
        --testnet-magic $testnet_number  \
        --out-file tx.signed  \
    >> transaction.log 2>&1 

    cardano-cli transaction submit  \
        --testnet-magic $testnet_number  \
        --tx-file tx.signed  \
    >> transaction.log 2>&1

    master_addr_funds_updated=false
    for i in $(seq 1 15); 
    do
        sleep 4
        cardano-cli query utxo  \
            --address $master_address \
            --testnet-magic $testnet_number \
            --out-file master_address_funds.txt \
        >> transaction.log 2>&1

        master_address_utxo_current=$(cat master_address_funds.txt | jq -r 'keys[0]')

        if [ $master_address_utxo != $master_address_utxo_current ]; then
            master_address_utxo=$master_address_utxo_current
            master_addr_funds_updated=true
            break
        fi
    done

    if [ $master_addr_funds_updated = false ]; then
        echo "Funds at master wallet not updated within a minute. Exiting script." 
        exit 1
    fi
done < addresses.txt 

echo "Script successfully finished." 

# The loop above could be compressed into the code below which does not work because bash has
# an issue to handle the " or ' character when passing it to the cardanoč-cli. This is needed in 
# the --tx-out part. If executing the commend that gets printed to the terminal by hand it works.  
<<'END'
transaction_build_part1='cardano-cli transaction build 
                            --babbage-era 
                            --testnet-magic '$testnet_number' 
                            --tx-in '$master_address_utxo' '

transaction_build_part3='--change-address '$master_address' 
                         --out-file tx.body 
                         >> transaction.log 2>&1'

transaction_build_part2=""
while IFS= read -r user_address; do
    tx_out_part="--tx-out '$user_address + $((1000000*$ada_amount_per_wallet)) lovelace' "
    transaction_build_part2="$transaction_build_part2$tx_out_part"
done < addresses.txt 

transaction_build="$transaction_build_part1$transaction_build_part2$transaction_build_part3"

echo "Command for sending ADA to all addresses in addresses.txt."
echo $transaction_build 

# Executing the command. Does not work. 
$transaction_build
# or 
# bash -c "$transaction_build"
END