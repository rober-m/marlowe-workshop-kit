
# Scripts for setting up and funding cardano wallets

This folder contains bash scripts for creating arbitrary number of cardano wallets and fund them with test ADA. The sections below guide you through the workflow and explain how to use the scripts. 

**All scripts require the `cardano-node` and `cardano-cli` installed execpt the *generate_seeds_and_addresses_1.sh* script. The `cardano-node` also has to be running and synced.** 

Instructions for installing and running the `cardano-node` and other cardano tools can be found at the bottom of this page. 

Before running the scripts you have to give them executable permission: 
```console
chmod +x <script_name>
```

Setting up master address and fund it with test ADA
---------------------------------------------------

The *create_and_fund_master_address.sh* script creates a signing and verification key and stores the address in the *master.addr* file. Then it requests 10.000 test ADA from the Cardano Faucet via the Faucet API. 

The script takes in the name of the testnet which can be either *preview* or *preprod*. Example command:
```console
./create_and_fund_master_address.sh preview
```

Generating seeds and cardano addresses
--------------------------------------

The *generate_seeds_and_addresses_1.sh* script generates a user requested number of wallet seeds and addresses beloning to the wallets and stores them in the *seeds.txt* and *addresses.txt* files. The *generate_seeds_and_addresses_2.sh* script does the same. The difference between them is following: 
* Script 1 uses the `cardano-address` tool which does not require a running `cardano-node`. In addition to the *seeds.txt* and *addresses.txt* files it creates the *wallet_files* folder where it stores the seeds and addresses for each wallet in an individual file. The tool can be installed on Windows and Linux. 
* Script 2 uses the `cardano-wallet` tool which does require a running and synced `cardano-node`. With this script you can also set a passphrase for each of the wallets. The tool can be installed on Windows, Mac OS and Linux. 

Both scripts take in the number of wallets we want to generate and the second script also takes in the passphrase which will be set the same for all wallets. The passphrase has to be at least 10 characters long. Example command:
```console
./generate_seeds_and_addresses_1.sh 50 
./generate_seeds_and_addresses_2.sh 50 passphrase12 
```

To install the `cardano-address` tool download the zipped file under the Assets section from the [cardano-address GitHub page](https://github.com/IntersectMBO/cardano-addresses/releases). Unzip the file and add the `cardano-address` executable file to your system path, e.g. copy them to `/usr/local/bin/`. 

To install the `cardano-wallet` tool download the zipped file under the Assets section from the [cardano-wallet GitHub page](https://github.com/cardano-foundation/cardano-wallet#obtaining-cardano-wallet). Unzip the file and add the `cardano-wallet` executable file to your system path, e.g. copy them to `/usr/local/bin/`. 

The *generate_seeds_and_addresses_2.sh* script requires `cardano-wallet` server running and synced. To startup the server execute the following command:
```console
cardano-wallet serve \
--port 1337 \
--testnet <path/to/byron-genesis.json> \
--database <path/to/db> \
--node-socket $CARDANO_NODE_SOCKET_PATH
```

The *byron-genesis.json* is part of the `cardano-node` configuration. Instructions for installing the node and obtaining the configuration files can be found at the bottom of this page. The *db/* folder will be created in the folder from where you started the `cardano-node`. 

You can check if the cardano-wallet server is synced with the following command:
```console
curl --url http://localhost:1337/v2/network/information | jq
```
The *status* filed of the *sync_progress* element will say *ready* in case the cardano-wallet server is synced. 

Sending funds to cardano addresses
----------------------------------

The *slow_send_funds_to_addresses.sh* script sends a user defined amount of ADA to all addresses listed in the *addresses.txt* file. The reason why it is prefixed with *slow* is because it sends the ADA one transaction at a time to each of the addresses. You can also use the *send_funds_to_addresses.py* python script that generates the *send_funds_to_addresses.sh* script which works the same as the slow script but sends the ADA to all addresses in one transaction. You can generate it as:
```console
python send_funds_to_addresses.py 
```

Both scripts assume the master address from which the ADA gets send is stored in the *master.addr* file and the singing key for the master address is stored in the *master.skey* file. These files get generated if you execute the *create_and_fund_master_address.sh* script. 

Both scripts send funds from the first UTXO listed under this address. If your master address contains multiple UTXOs you can bundle them into one with the script *bundle_master_addr_utxos.sh*. You can read a description of that script and how to use it in the next section. 

Also in both scripts it is checked that the number of wallets taken from the *addresses.txt* multiplied with the ADA per one wallet does not exceed 10.000 ADA, which is the default value you can request from the Cardano Faucet. If you have an address containing more then 10.000 ADA you can change that number by hand in both scripts where security checks are made in the begining.  

Both scripts take in the testnet name which can be either *preview* or *preprod* and ADA amount per wallet. Example command: 
```console
./send_funds_to_addresses.sh preview 10
./slow_send_funds_to_addresses.sh preview 10
```

Bundle UTXOs at address into one
--------------------------------

The *bundle_master_addr_utxos.sh* script uses the address stored in *master.addr* file and the signing key stored in *master.skey* to create a transaction that sends all funds from this address back to this address by creating a single UTXO. 

The script takes in the name of the testnet which can be either *preview* or *preprod*. Example command: 
```console
./bundle_master_addr_utxos.sh preview
```

Installing the `cardano-node` and other command line tools
----------------------------------------------------------

To run a cardano node download it from [here](https://github.com/input-output-hk/cardano-node/releases) and install it. The installer files are located under the Assets section that needs to be expanded. Add all executable files to you system path, e.g. copy them to `/usr/local/bin/`. 

Then download the configurations files for the Preview testnet from [here](https://book.world.dev.cardano.org/environments.html#preview-testnet) or for the Preprod testnet from [here](https://book.world.dev.cardano.org/environments.html#pre-production-testnet). 

From the folder that contains your configuration files run: 
```console
cardano-node run \
 --topology topology.json \
 --database-path db \
 --socket-path node.socket \
 --host-addr 0.0.0.0 \
 --port 3001 \
 --config config.json
```

The `node.socket` file will be created in the folder from where you ran the above command. Stop the node and add to the end of your *.bashrc* file that is located in your HOME folder the follwoing line:
```console
export CARDANO_NODE_SOCKET_PATH="$HOME/<path>/<to>/node.socket"
```
Source the *.bashrc* file:
```console
source ~/.bash.rc
```
Start the cardano node again. You can check the sync progress with the following command:
```console
cardano-cli query tip --testnet-magic <testnet_number> 
```
For the testnet number use 1 for preprod and 2 for preview. 
