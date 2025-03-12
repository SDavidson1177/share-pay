include .env_dev

build:
	forge build --extra-output-files abi

serve:
	anvil -b 4 --chain-id 1337

setup: clean
	cp .env_dev .env_orig

dev: setup
	bash -c "forge create --rpc-url ${DEV_RPC} --private-key ${DEPLOY_PRIVATE_KEY} src/SharePay.sol:SharePay" | tee tmp.txt
	cat tmp.txt | egrep Deployed | awk '{ print $$3 }' | tee tmp.txt
	bash -c "forge create --rpc-url ${DEV_RPC} --private-key ${DEPLOY_PRIVATE_KEY} src/SharePayProxy.sol:SharePayProxy --constructor-args \"$$(cat tmp.txt)\" \"0x8129fc1c\"" | tee tmp2.txt
	cat tmp2.txt | egrep Deployed | awk '{ print $$3 }' | tee tmp2.txt
	echo "" >> .env_dev
	echo VITE_CONTRACT_ADDRESS=\"$$(cat tmp2.txt)\" >> .env_dev
	cp .env_dev ${DOTENV_LOCATION}/.env
	rm tmp.txt
	rm tmp2.txt

clean:
	- cp .env_orig .env_dev && rm .env_orig
	- rm ${DOTENV_LOCATION}/.env

