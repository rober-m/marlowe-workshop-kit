#!/bin/bash

# Script that generates wallet seeds and addresses of type base with the cardano-address tool 

set -e
number_of_wallets=$1

# Security checks 
if [ $number_of_wallets -lt 1 ]; then
    echo "Number of wallets has to be a positive number." 
    exit 1 
fi 

mkdir "wallet_files"

# Loop for generating seeds and addresses of type base that contain a staking part 
for i in $(seq 1 $number_of_wallets)
do
    seed=$(cardano-address recovery-phrase generate --size 15) 
    echo $seed > "wallet_files/phrase_$i.prv"
    echo $seed >> "seeds.txt"

    rootPK=$(echo $seed | cardano-address key from-recovery-phrase Shelley)
    echo $rootPK > "wallet_files/root_$i.xsk" 

    extendedSVK=$(echo $rootPK | cardano-address key child 1852H/1815H/0H/2/0 | cardano-address key public --with-chain-code)
    echo $extendedSVK > "wallet_files/stake_$i.xvk"

    paymentVK=$(echo $rootPK | cardano-address key child 1852H/1815H/0H/0/0 | cardano-address key public --with-chain-code)
    echo $paymentVK > "wallet_files/addr_$i.xvk"

    paymentADDR=$(echo $paymentVK | cardano-address address payment --network-tag testnet)
    echo $paymentADDR > "wallet_files/payment_$i.addr"

    delegatedPADDR=$(echo $paymentADDR | cardano-address address delegation $extendedSVK)
    echo $delegatedPADDR > "wallet_files/base_$i.addr" 
    echo $delegatedPADDR >> "addresses.txt" 
done

