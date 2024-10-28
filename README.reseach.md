# Research

## anvil

To run the node

```shell
anvil --no-mining --state anvil --code-size-limit 30000000
```

## hardhat

```shell
pnpm run node
```

Deployment

```shell
forge create contracts/Lock.sol:Lock --constructor-args-path --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

TODO: next command is failing

```shell
forge create --root lib/royco src/VaultOrderbook.sol:VaultOrderbook --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --gas-limit 200000
```

```shell
forge verify-contract --root lib/royco --verifier blockscout --verifier-url 'http://localhost/api/' 0x5FbDB2315678afecb367f032d93F642f64180aa3 src/VaultOrderbook.sol:VaultOrderbook
```

Deploy to sepolia using test wallet

```shell
forge create --root lib/royco src/VaultOrderbook.sol:VaultOrderbook --private-key 49c2a017327537646bccf0e4814624aa82d10595f79ea86793c5c242b4ee3891 -r https://1rpc.io/sepolia
```

```shell
forge verify-contract --root lib/royco --verifier blockscout --verifier-url 'http://localhost/api/' 0x5FbDB2315678afecb367f032d93F642f64180aa3 src/VaultOrderbook.sol:VaultOrderbook
```

## Dahlia

```shell
forge verify-contract 0x5FbDB2315678afecb367f032d93F642f64180aa3 contracts/Dahlia.sol:Dahlia --verifier sourcify --verifier-url http://localhost:5555/verify --rpc-url 'http://localhost:8546' --retries 1
```
