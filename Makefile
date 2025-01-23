include ../.env

setup: clean
	cp ../.env ../.env_orig

dev: setup
	bash -c "forge create --rpc-url ${DEV_RPC} --private-key ${DEPLOY_PRIVATE_KEY} src/SharePay.sol:SharePay" | tee tmp.txt
	cat tmp.txt | egrep Deployed | awk '{ print $$3 }' | tee tmp.txt
	echo "" >> ../.env
	echo CONTRACT_ADDRESS=$$(cat tmp.txt) >> ../.env

clean:
	- cp ../.env_orig ../.env && rm ../.env_orig

