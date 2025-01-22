# Timelock
ENCODED_ARGS=$(cast abi-encode \
  "constructor(address, uint256)" \
  0xd940909AE50e084706e479604BAe660b5F932E18 \
  "172800")

forge verify-contract \
  0x54d964e63e75fb96556a08300cbd3efa5efccd38 \
  ./src/oracles/contracts/Timelock.sol:Timelock \
  --verifier-url "https://api.routescan.io/v2/network/testnet/evm/80000/etherscan" \
  --etherscan-api-key "verifyContract" \
  --num-of-optimizations 200 \
  --watch \
  --compiler-version "v0.8.27" \
  --constructor-args $ENCODED_ARGS

# DahliaPythOracleFactory
ENCODED_ARGS=$(cast abi-encode \
  "constructor(address, address)" \
  0x54d964e63e75fb96556a08300cbd3efa5efccd38 \
  0xDd24F84d36BF92C65F92307595335bdFab5Bbd21)

forge verify-contract \
  0x271921891b0ada381e4bf4a3bec47982204ed2b9 \
  ./src/oracles/contracts/DahliaPythOracleFactory.sol:DahliaPythOracleFactory \
  --verifier-url "https://api.routescan.io/v2/network/testnet/evm/80000/etherscan" \
  --etherscan-api-key "verifyContract" \
  --num-of-optimizations 200 \
  --watch \
  --compiler-version "v0.8.27" \
  --constructor-args $ENCODED_ARGS

# DahliaPythOracle_0
ENCODED_ARGS=$(cast abi-encode \
  "constructor(address,(address,bytes32,address,bytes32),(uint256,uint256),address)" \
  0xd940909AE50e084706e479604BAe660b5F932E18 \
  "(0x1da4dF975FE40dde074cBF19783928Da7246c515,0xc1304032f924ebde0d52dd804ff7e7d095f7b4d4eff809cae7f12b7136e089c0,0x2d93FbcE4CffC15DD385A80B3f4CC1D4E76C38b3,0x86d196443d86a992f6c4ce38779cdfa36b649e43052ef8bedbe0b503029a94c2)" \
  "(86400,86400)" \
  0xDd24F84d36BF92C65F92307595335bdFab5Bbd21)

forge verify-contract \
  0xd9c16b4bf4b4136fc930dc40a046104cc3ca0451 \
  ./src/oracles/contracts/DahliaPythOracle.sol:DahliaPythOracle \
  --verifier-url "https://api.routescan.io/v2/network/testnet/evm/80000/etherscan" \
  --etherscan-api-key "verifyContract" \
  --num-of-optimizations 200 \
  --watch \
  --compiler-version "v0.8.27" \
  --constructor-args $ENCODED_ARGS

# DahliaPythOracle_1
ENCODED_ARGS=$(cast abi-encode \
  "constructor(address,(address,bytes32,address,bytes32),(uint256,uint256),address)" \
  0xd940909AE50e084706e479604BAe660b5F932E18 \
  "(0x6969696969696969696969696969696969696969,0x40dd8c66a9582c51a1b03a41d6c68ee5c2c04c8b9c054e81d0f95602ffaefe2f,0x015fd589F4f1A33ce4487E12714e1B15129c9329,0x41f3625971ca2ed2263e78573fe5ce23e13d2558ed3f2e47ab0f84fb9e7ae722)" \
  "(86400,86400)" \
  0xDd24F84d36BF92C65F92307595335bdFab5Bbd21)

forge verify-contract \
  0x922d6c42cf49f01930f16ea9fe4531dec45163c0 \
  ./src/oracles/contracts/DahliaPythOracle.sol:DahliaPythOracle \
  --verifier-url "https://api.routescan.io/v2/network/testnet/evm/80000/etherscan" \
  --etherscan-api-key "verifyContract" \
  --num-of-optimizations 200 \
  --watch \
  --compiler-version "v0.8.27" \
  --constructor-args $ENCODED_ARGS
