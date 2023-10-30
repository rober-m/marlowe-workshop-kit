

# Begining of the script
parameters = \
"""
#!/bin/bash

# Script that sends a fixed amount of ADA to all addresses in addresses.txt from the 
# master address contained in master.addr. Sends all the funds in one transaction.   

# Exit script in case of error 
set -e

# Input parameters to the script
testnet=$1
ada_amount_per_wallet=$2

# Master address and signing keys
master_skey="master.skey"
master_address=$(cat master.addr)

addresses_file_line_count=$(wc -l addresses.txt)
stringarray=($addresses_file_line_count)
number_of_wallets=${stringarray[0]}
"""

setting_testnet = \
"""
# Setting the testnet number 
if [ $testnet = "preprod" ]; then
    testnet_number=1
elif [ $testnet = "preview" ]; then
    testnet_number=2
else
    echo "Testnet parameter can only be preview or preprod."
    exit 1
fi
"""

security_checks = \
"""
# Computing the master address UTXO and funds 
msg="Querying funds for master address." 
echo $msg && echo $msg >> transaction.log 
cardano-cli query utxo  \\
    --address $master_address \\
    --testnet-magic $testnet_number \\
    --out-file master_address_funds.txt \\
>> transaction.log 2>&1

master_address_utxo=$(cat master_address_funds.txt | jq "keys[0]")
master_address_lovelace=$(cat master_address_funds.txt | jq ".$master_address_utxo.value.lovelace")
master_address_ada=$((master_address_lovelace/1000000))

# Checking if there are enough funds present at the first UTXO of the master address 
if [ $((master_address_ada-2)) -lt $(($number_of_wallets*$ada_amount_per_wallet)) ]; then
    echo "Total amount of $(($number_of_wallets*$ada_amount_per_wallet)) ADA to send" 
    echo "exceeds the amount of $master_address_ada ADA available minus 2 ADA for fees."  
    exit 1
fi
"""

# Transaction build command
build_part1 = \
"""
# Building, singing and submitting the transaction 
msg="Building transaction." 
echo $msg && echo $msg >> transaction.log 
cardano-cli transaction build  \\
    --babbage-era \\
    --testnet-magic $testnet_number \\
    --tx-in $master_address_utxo \\"""

build_part3 = \
"""
    --change-address $master_address \\
    --out-file tx.body \\
    >> transaction.log 2>&1
"""

build_part2 = ""
with open('addresses.txt') as fp:
    for line in fp:
        address = line.replace("\n", "")
        build_part2 += "\n    --tx-out \"" + address + \
                       " + $((1000000*$ada_amount_per_wallet)) lovelace\" \\"

# Transaction sign and submit commands
sing_and_submit = \
"""
msg="Signing transaction." 
echo $msg && echo $msg >> transaction.log 
cardano-cli transaction sign  \\
    --tx-body-file tx.body  \\
    --signing-key-file $master_skey  \\
    --testnet-magic $testnet_number  \\
    --out-file tx.signed  \\
>> transaction.log 2>&1 

msg="Submitting transaction." 
echo $msg && echo $msg >> transaction.log 
cardano-cli transaction submit  \\
    --testnet-magic $testnet_number  \\
    --tx-file tx.signed  \\
>> transaction.log 2>&1
"""

# Code for checking funds of last address 
check_funds = \
"""
# Checking if funds at last address arrived 
msg="Checking if funds at last user address arrived." 
echo $msg && echo $msg >> transaction.log 
user_addr_funds_updated=false
for i in $(seq 1 15); 
do
    sleep 4
    echo "Iteration $i." >> transaction.log 
    echo "Querying funds for master address." >> transaction.log 
    cardano-cli query utxo  \\
        --address $master_address \\
        --testnet-magic $testnet_number \\
        --out-file master_address_funds.txt \\
    >> transaction.log 2>&1

    master_address_utxo=$(cat master_address_funds.txt | jq -r 'keys[0]')
    master_address_utxo_array=(${master_address_utxo//#/ })
    master_address_hash=${master_address_utxo_array[0]}

    echo "Querying funds for last user address." >> transaction.log 
    cardano-cli query utxo  \\
        --address """ + address + """ \\
        --testnet-magic $testnet_number \\
        --out-file user_address_funds.txt \\
    >> transaction.log 2>&1

    last_user_address_funds=$(cat user_address_funds.txt)

    echo "Master address transaction hash: $master_address_hash" >> transaction.log 
    echo "User address funds: $last_user_address_funds" >> transaction.log 

    if [[ "$last_user_address_funds" == *"$master_address_hash"* ]]; then
        echo "Last user address received funds."
        user_addr_funds_updated=true
        break
    fi
done

if [ $user_addr_funds_updated = false ]; then
    echo "Funds at last user address did not arrived within a minute. Exiting script." 
    exit 1
fi
"""

# Writing the entire bash script to a file 
entire_script = parameters + setting_testnet + security_checks + \
                build_part1 + build_part2 + build_part3 + \
                sing_and_submit + check_funds 

with open("send_funds_to_addresses.sh", "w") as bash_file:
    bash_file.write(entire_script)

