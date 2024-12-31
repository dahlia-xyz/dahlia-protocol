# WrappedVault
forge verify-contract \
  0x50adb4bc72919bce00da0382fae354f52555855c \
  ./src/royco/contracts/WrappedVault.sol:WrappedVault \
  --verifier-url "https://api.routescan.io/v2/network/testnet/evm/80000/etherscan" \
  --etherscan-api-key "verifyContract" \
  --num-of-optimizations 200 \
  --compiler-version "v0.8.27+commit.40a35a09"

## DahliaRegistry
#ENCODED_ARGS=$(cast abi-encode \
#  "constructor(address)" \
#  0x56929D12646A2045de60e16AA28b8b4c9Dfb0441)
#
#forge verify-contract \
#  0x88dd1ae59f48199920b49bb9a1ce7db9226fe8fc \
#  ./src/core/contracts/DahliaRegistry.sol:DahliaRegistry \
#  --verifier-url "https://api.routescan.io/v2/network/testnet/evm/80000/etherscan" \
#  --etherscan-api-key "verifyContract" \
#  --num-of-optimizations 200 \
#  --compiler-version "v0.8.27+commit.5d80cfab" \
#  --constructor-args $ENCODED_ARGS
#
# Dahlia
#ENCODED_ARGS=$(cast abi-encode \
#  "constructor(address, address)" \
#  0x56929D12646A2045de60e16AA28b8b4c9Dfb0441 \
#  0x88dd1ae59f48199920b49bb9a1ce7db9226fe8fc)
#
#forge verify-contract \
#  0x96B6424E595F6B0eEA6e2dA5Ea41Fc3e263B3804 \
#  ./src/core/contracts/Dahlia.sol:Dahlia \
#  --verifier-url "https://api.routescan.io/v2/network/testnet/evm/80000/etherscan" \
#  --etherscan-api-key "verifyContract" \
#  --num-of-optimizations 200 \
#  --compiler-version "v0.8.27+commit.5d80cfab" \
#  --constructor-args $ENCODED_ARGS

# WrappedVaultFactory
#ENCODED_ARGS=$(cast abi-encode \
#  "constructor(address, address, uint256, uint256, address, address, address)" \
#  0x50AdB4bc72919bCE00da0382FAe354f52555855C \
#  0x56929D12646A2045de60e16AA28b8b4c9Dfb0441 \
#  10000000000000000 \
#  20000000000000000 \
#  0x56929D12646A2045de60e16AA28b8b4c9Dfb0441 \
#  0x19112AdBDAfB465ddF0b57eCC07E68110Ad09c50 \
#  0x96B6424E595F6B0eEA6e2dA5Ea41Fc3e263B3804 \
#  )
#
#forge verify-contract \
#  0xaca13f8896b69e47816a7e3db9be89ce876982ce \
#  ./src/royco/contracts/WrappedVaultFactory.sol:WrappedVaultFactory \
#  --verifier-url "https://api.routescan.io/v2/network/testnet/evm/80000/etherscan" \
#  --etherscan-api-key "verifyContract" \
#  --num-of-optimizations 200 \
#  --compiler-version "v0.8.27+commit.5d80cfab" \
#  --constructor-args $ENCODED_ARGS

## IRMFactory
#forge verify-contract \
#  0xeda157aaa70e211bda032f4d3fbba047ac540ddc \
#  ./src/irm/contracts/IrmFactory.sol:IrmFactory \
#  --verifier-url "https://api.routescan.io/v2/network/testnet/evm/80000/etherscan" \
#  --etherscan-api-key "verifyContract" \
#  --num-of-optimizations 200 \
#  --compiler-version "v0.8.27+commit.5d80cfab"

# VariableIrm
#ENCODED_ARGS=$(cast abi-encode \
#  "constructor((uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256))" \
#  "(88000, 92000, 90000, 604800, 15824704600, 158247046000, 31649410, 200000000000000000)")
#
#forge verify-contract \
#  0xaca13f8896b69e47816a7e3db9be89ce876982ce \
#  ./src/irm/contracts/VariableIrm.sol:VariableIrm \
#  --verifier-url "https://api.routescan.io/v2/network/testnet/evm/80000/etherscan" \
#  --etherscan-api-key "verifyContract" \
#  --num-of-optimizations 200 \
#  --compiler-version "v0.8.27+commit.5d80cfab" \
#  --constructor-args $ENCODED_ARGS
