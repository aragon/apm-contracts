require('babel-register');
require('babel-polyfill');

var HDWalletProvider = require('truffle-hdwallet-provider');

// mnemonic in env variable (address: 0x4c7c86b2a848508494f32033c1a8694d98712a9b) owns aragonpm.test and aragon.test, and is owner of deployed registries
const mnemonic = process.env.APM_MNEMONIC || 'burger burger burger burger burger burger burger burger burger burger burger burger';

module.exports = {
  networks: {
    development: {
      network_id: 15,
      provider: require('ethereumjs-testrpc').provider({ gasLimit: 1e8, network_id: 15 }),
      gas: 9e6,
    },
    rpc: {
      network_id: 15,
      host: 'localhost',
      port: 8545,
      gas: 4.7e6,
    },
    ropsten: {
      network_id: 3,
      provider: new HDWalletProvider(mnemonic, 'https://ropsten.infura.io/'),
      gas: 4.712e6,
    },
    kovan: {
      network_id: 42,
      provider:  new HDWalletProvider(mnemonic, 'https://kovan.aragon.one'),
      gas: 4.6e6,
    },
    coverage: {
      host: "localhost",
      network_id: "*",
      port: 8555,
      gas: 0xffffffffff,
      gasPrice: 0x01
    },
  },
  build: {},
}
