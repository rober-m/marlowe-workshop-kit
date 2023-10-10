#!/bin/bash 

# Exit script in case of error 
set -e

# Input parameters 
number_of_wallets=$1 
wallet_passphrase=$2

# Security checks 
if [ $number_of_wallets -lt 1 ]; then
    echo "Number of wallets has to be a positive number." 
    exit 1 
fi 

passphrase_size=${#wallet_passphrase} 
if [ $passphrase_size -lt 10 ]; then
    echo "Passphrase has to be at least 10 characters long." 
    exit 1 
fi 

# Main loop that generates the seeds and wallet addresses 
echo "Generating wallet seeds and addresses." 
for i in $(seq 1 $number_of_wallets);
do
    seed=$(cardano-wallet recovery-phrase generate | jq -c --raw-input 'split(" ")')
    echo $seed >> seeds.txt

    # The --no-progress-meter  option is available only for curl 7.67.0+ 
    wallet_data=$(curl --request POST \
                       --url http://localhost:1337/v2/wallets \
                       --header 'Content-Type: application/json' \
                       --data '{
                           "name": "test_cf_1",
                           "mnemonic_sentence": '$seed',
                           "passphrase": "'$wallet_passphrase'"
                               }' \
                       --no-progress-meter | jq)
    wallet_id=$(echo $wallet_data | jq '.id' | tr -d '"') 

    # This code block is not needed. The address can be funded before it is synced. 
: <<'END'
    check_passed=false
    for i in $(seq 1 80); 
    do
        wallet_status=$(curl --url http://localhost:1337/v2/wallets/$wallet_id | jq '.state')
        sleep 10
        if [[ "$wallet_status" == *"ready"* ]];
        then
            check_passed=true
            break
        fi
    done

    if [ $check_passed = false ]; then
        echo "Could not setup wallet with id $wallet_id."
        break
    fi
END

    address=$(curl --url 'http://localhost:1337/v2/wallets/'$wallet_id'/addresses?state=unused'  \
                   --no-progress-meter | jq '.[0]' | jq '.id' | tr -d '"')
    echo $address >> addresses.txt
done

echo "Seeds stored in seeds.txt." 
echo "Addresses stored in addresses.txt." 
