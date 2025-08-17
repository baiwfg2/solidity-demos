## setup

```
forge install smartcontractkit/chainlink-evm --shallow
forge install cyfrin/foundry-devops --shollow
forge install transmissions11/solmate --shallow
forge install openzeppelin/contracts@4.9.6 --shallow

# chainlink depends on 4.9.6
forge install openzeppelin/openzeppelin-contracts@4.9.6 --shallow
```

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
