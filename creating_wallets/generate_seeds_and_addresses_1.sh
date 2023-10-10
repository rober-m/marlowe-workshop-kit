#!/bin/bash

# Script that generates wallet seeds and addresses with the cardano-address tool 

set -e
number_of_wallets=$1

# Security checks 
if [ $number_of_wallets -lt 1 ]; then
    echo "Number of wallets has to be a positive number." 
    exit 1 
fi 

mkdir "wallet_files"

# Loop for generating seeds and addresses 
for i in $(seq 1 $number_of_wallets)
do
    seed=$(cardano-address recovery-phrase generate --size 15) 
    echo $seed > "wallet_files/phrase_$i.prv"
    echo $seed >> "seeds.txt"
    cardano-address key from-recovery-phrase Shelley < "wallet_files/phrase_$i.prv" > "wallet_files/root_$i.xsk"
    cardano-address key child 1852H/1815H/0H/0/0 < "wallet_files/root_$i.xsk" | cardano-address key public --with-chain-code > "wallet_files/addr_$i.xvk"
    address=$(cardano-address address payment --network-tag testnet < "wallet_files/addr_$i.xvk") 
    echo $address > "wallet_files/payment_$i.addr"
    echo $address >> "addresses.txt" 
done

