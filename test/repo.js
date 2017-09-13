const { assertInvalidOpcode } = require('./helpers/assertThrow')

const Repo = artifacts.require('Repo')

contract('Repo', accounts => {
    let repo = {}

    beforeEach(async () => {
        repo = await Repo.new()
    })

    it('computes correct valid bumps', async () => {
        await assert.isTrue(await repo.isValidBump([0, 0, 0], [0, 0, 1]))
        await assert.isTrue(await repo.isValidBump([0, 0, 0], [0, 1, 0]))
        await assert.isTrue(await repo.isValidBump([0, 0, 0], [1, 0, 0]))
        await assert.isTrue(await repo.isValidBump([1, 4, 7], [2, 0, 0]))
        await assert.isTrue(await repo.isValidBump([147, 4, 7], [147, 5, 0]))

        await assert.isFalse(await repo.isValidBump([0, 0, 1], [0, 0, 1]))
        await assert.isFalse(await repo.isValidBump([0, 1, 0], [0, 2, 1]))
        await assert.isFalse(await repo.isValidBump([0, 0, 2], [0, 0, 1]))
        await assert.isFalse(await repo.isValidBump([2, 1, 0], [2, 2, 1]))
        await assert.isFalse(await repo.isValidBump([0, 1, 2], [1, 1, 2]))
        await assert.isFalse(await repo.isValidBump([0, 0, Math.pow(2, 16)], [0, 0, Math.pow(2, 16) - 1]))
    })

    it('owner can transfer ownership', async () => {
        await repo.transferOwnership(accounts[2])
        assert.equal(await repo.owner(), accounts[2], 'ownership should have been transfered')
    })

    it('cannot create invalid first version', async () => {
        return assertInvalidOpcode(async () => {
            await repo.newVersion([1, 1, 0], '0x00', '0x00')
        })
    })

    it('non-owners cannot create versions', async () => {
        return assertInvalidOpcode(async () => {
            await repo.newVersion([1, 0, 0], '0x00', '0x00', { from: accounts[2] })
        })
    })

    context('creating initial version', () => {
        const initialCode = accounts[8] // random addr, irrelevant
        const initialContent = '0x12'

        beforeEach(async () => {
            await repo.newVersion([1, 0, 0], initialCode, initialContent)
        })

        const assertVersion = (versionData, semanticVersion, code, contentUri) => {
            const [[maj, min, pat], addr, content] = versionData

            assert.equal(maj, semanticVersion[0], 'major should match')
            assert.equal(min, semanticVersion[1], 'minor should match')
            assert.equal(pat, semanticVersion[2], 'patch should match')

            assert.equal(addr, code, 'code should match')
            assert.equal(content, contentUri, 'content should match')
        }

        it('version is fetcheable as latest', async () => {
            assertVersion(await repo.getLatest(), [1, 0, 0], initialCode, initialContent)
        })

        it('version is fetcheable by semantic version', async () => {
            assertVersion(await repo.getBySemanticVersion([1, 0, 0]), [1, 0, 0], initialCode, initialContent)
        })

        it('version is fetcheable by contract address', async () => {
            assertVersion(await repo.getLatestForContractAddress(initialCode), [1, 0, 0], initialCode, initialContent)
        })

        it('version is fetcheable by version id', async () => {
            assertVersion(await repo.getByVersionId(1), [1, 0, 0], initialCode, initialContent)
        })

        it('fails when setting contract in non major version', async () => {
            return assertInvalidOpcode(async () => {
                await repo.newVersion([1, 1, 0], accounts[2], initialContent)
            })
        })

        it('fails when version bump is invalid', async () => {
            return assertInvalidOpcode(async () => {
                await repo.newVersion([1, 1, 0], initialContent, initialContent)
            })
        })

        context('adding new version', async () => {
            const newCode = accounts[9] // random addr, irrelevant
            const newContent = '0x13'

            beforeEach(async () => {
                await repo.newVersion([2, 0, 0], newCode, newContent)
            })

            it('new version is fetcheable as latest', async () => {
                assertVersion(await repo.getLatest(), [2, 0, 0], newCode, newContent)
            })

            it('new version is fetcheable by semantic version', async () => {
                assertVersion(await repo.getBySemanticVersion([2, 0, 0]), [2, 0, 0], newCode, newContent)
            })

            it('new version is fetcheable by contract address', async () => {
                assertVersion(await repo.getLatestForContractAddress(newCode), [2, 0, 0], newCode, newContent)
            })

            it('new version is fetcheable by version id', async () => {
                assertVersion(await repo.getByVersionId(2), [2, 0, 0], newCode, newContent)
            })

            it('old version is fetcheable by semantic version', async () => {
                assertVersion(await repo.getBySemanticVersion([1, 0, 0]), [1, 0, 0], initialCode, initialContent)
            })

            it('old version is fetcheable by contract address', async () => {
                assertVersion(await repo.getLatestForContractAddress(initialCode), [1, 0, 0], initialCode, initialContent)
            })

            it('old version is fetcheable by version id', async () => {
                assertVersion(await repo.getByVersionId(1), [1, 0, 0], initialCode, initialContent)
            })
        })
    })
})
