const { assertInvalidOpcode } = require('./helpers/assertThrow')
const namehash = require('eth-ens-namehash').hash

const ENS = artifacts.require('ENS')
const RepoRegistry = artifacts.require('RepoRegistry')
const AddrResolver = artifacts.require('AddrResolver')
const Repo = artifacts.require('Repo')
const ForwarderFactory = artifacts.require('ForwarderFactory')

contract('Repo Registry', accounts => {
    let ens, registry = {}

    const ensOwner = accounts[0]

    const rootNode = namehash('aragonpm.eth')

    before(async () => {
        // Simulate ENS and ownership of aragonpm.eth
        ens = await ENS.new()
        ens.setSubnodeOwner('0x00', web3.sha3('eth'), ensOwner)
        ens.setSubnodeOwner(namehash('eth'), web3.sha3('aragonpm'), ensOwner)
    })

    beforeEach(async () => {
        const masterRepo = await Repo.new()
        const factoryInitcode = ForwarderFactory.binary.replace('beefbeefbeefbeefbeefbeefbeefbeefbeefbeef', masterRepo.address.slice(2))
        const forwarderFactory = await ForwarderFactory.new({ data: factoryInitcode })
        registry = await RepoRegistry.new(ens.address, rootNode, forwarderFactory.address)
        await ens.setOwner(rootNode, registry.address)
    })

    afterEach(async () => {
        await registry.setRootOwner(ensOwner) // transfer name ownership back
    })

    it('registry should be name owner for aragonpm.eth', async () => {
        assert.equal(await ens.owner(namehash('aragonpm.eth')), registry.address, 'should be owner')
    })

    it('can transfer ownership', async () => {
        await registry.transferOwnership(accounts[1])
        assert.equal(await registry.owner(), accounts[1], 'owner should have changed correctly')

        await registry.transferOwnership(accounts[0], { from: accounts[1] }) // so afterEach hook doesnt break
    })

    it('fails when non-owner tries to set root owner', async () => {
        return assertInvalidOpcode(async () => {
            await registry.transferOwnership(accounts[1], { from: accounts[2] })
        })
    })

    context('creating test.aragonpm.eth repo', () => {
        let repoAddr = {}
        const repoOwner = accounts[1]

        const testName = namehash('test.aragonpm.eth')

        beforeEach(async () => {
            const receipt = await registry.newRepo('test', { from: repoOwner, gas: 2e6 })
            repoAddr = receipt.logs.filter(x => x.event == 'NewRepo')[0].args.repo
        })

        it('resolver is setup correctly', async () => {
            assert.equal(await ens.resolver(testName), registry.address, 'resolver should be set to registry')
            assert.equal(await AddrResolver.at(registry.address).addr(testName), repoAddr, 'resolver should resolve to repo address')
        })

        it('is owned by creator', async () => {
            assert.equal(await Repo.at(repoAddr).owner(), repoOwner, 'repo owner should be correct')
        })

        it('fails when creating repo with existing name', async () => {
            return assertInvalidOpcode(async () => {
                await registry.newRepo('test')
            })
        })
    })
})
