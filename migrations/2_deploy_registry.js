const namehash = require('eth-ens-namehash').hash

const ENS = artifacts.require('ENS')
const RepoRegistry = artifacts.require('RepoRegistry')
const Repo = artifacts.require('Repo')
const ForwarderFactory = artifacts.require('ForwarderFactory')

const ensAddrs = {
    mainnet: '0x314159265dd8dbb310642f98f50c066173c1259b',
    ropsten: '0x112234455C3a32FD11230C42E7Bccd4A84e02010',
}

let oldRegistryAddr = null
try { oldRegistryAddr = RepoRegistry.address } catch (e) {}

const name = 'aragonpm.test'
const rootNode = namehash(name)

let deployedENS = false
// if registry was previously deployed, setting address here will claim ENS name

const deployENS = (deployer, owner) => {
    const nameComponents = name.split('.').reverse()

    return deployer.deploy(ENS).then(() => {
        ens = ENS.at(ENS.address)
        return nameComponents.reduce((promise, comp, i) => {
            const rootNode = i > 0 ? namehash(nameComponents.slice(0, i)) : '0x00'
            return promise.then(() => ens.setSubnodeOwner(rootNode, web3.sha3(comp), owner))
        }, Promise.resolve()).then(() => {
            console.log('Deployed ENS instance at', ens.address)
            deployedENS = true
            return ens
        })
    })
}

module.exports = (deployer, network, accounts) => {
    console.log('Deploying registry on network', network)
    let ens = {}

    return deployer
        .then(() => {
            if (ensAddrs[network]) return Promise.resolve(ENS.at(ensAddrs[network]))
            return deployENS(deployer, accounts[0])
        })
        .then(ensCtr => {
            ens = ensCtr
            return Repo.new()
        })
        .then(masterRepo => {
            // replace beefbeef... placeholder in contract binary for actual repo address
            const repoPlaceholder = 'beefbeefbeefbeefbeefbeefbeefbeefbeefbeef'
            const repoAddr = masterRepo.address.slice(2)
            const factoryInitcode = ForwarderFactory.binary.replace(repoPlaceholder, repoAddr)
            return deployer.deploy(ForwarderFactory, { data: factoryInitcode })
        })
        .then(repoFactory => deployer.deploy(RepoRegistry, ens.address, rootNode, ForwarderFactory.address))
        .then(() => {
            console.log('Deployed registry at', RepoRegistry.address)

            if (!oldRegistryAddr || deployedENS) {
                console.log('Transfering name ownership')
                return ens.setOwner(rootNode, RepoRegistry.address)
            } else {
                console.log('Requesting name ownership from old registry')
                return RepoRegistry.at(oldRegistryAddr).setRootOwner(RepoRegistry.address)
            }
        })
        .then(() => RepoRegistry.at(RepoRegistry.address).setResolver())
}
