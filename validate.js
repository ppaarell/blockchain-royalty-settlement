const fs = require('fs');
const path = require('path');
const solc = require('solc');
const ganache = require('ganache');
const { ethers } = require('ethers');
const assert = require('assert');

function compile() {
  const contractsDir = path.join(__dirname, '..', 'contracts');
  const files = ['AssetRegistry.sol', 'LicenseTerms.sol', 'MintUSD.sol', 'RoyaltyEngine.sol', 'AuditCompliance.sol'];
  const input = {
    language: 'Solidity',
    sources: Object.fromEntries(files.map(f => [f, { content: fs.readFileSync(path.join(contractsDir, f), 'utf8') }])),
    settings: {
      optimizer: { enabled: true, runs: 200 },
      evmVersion: 'paris',
      outputSelection: { '*': { '*': ['abi', 'evm.bytecode.object'] } }
    }
  };
  function findImports(importPath) {
    const local = path.join(contractsDir, importPath);
    const nodeModule = path.join(__dirname, '..', 'node_modules', importPath);
    if (fs.existsSync(local)) return { contents: fs.readFileSync(local, 'utf8') };
    if (fs.existsSync(nodeModule)) return { contents: fs.readFileSync(nodeModule, 'utf8') };
    return { error: `Import not found: ${importPath}` };
  }
  const out = JSON.parse(solc.compile(JSON.stringify(input), { import: findImports }));
  const errs = (out.errors || []).filter(e => e.severity === 'error');
  if (errs.length) throw new Error(errs.map(e => e.formattedMessage).join('\n'));
  return out.contracts;
}

async function deploy(compiled, file, name, signer, args = []) {
  const artifact = compiled[file][name];
  const factory = new ethers.ContractFactory(artifact.abi, artifact.evm.bytecode.object, signer);
  const c = await factory.deploy(...args);
  await c.waitForDeployment();
  return c;
}

(async () => {
  const compiled = compile();
  const provider = new ethers.BrowserProvider(ganache.provider({ logging: { quiet: true }, chain: { hardfork: 'shanghai' } }));
  const [admin, creator, dsp, validator] = [await provider.getSigner(0), await provider.getSigner(1), await provider.getSigner(2), await provider.getSigner(3)];

  const asset = await deploy(compiled, 'AssetRegistry.sol', 'AssetRegistry', admin, ['CreativeAsset', 'CRAS']);
  const terms = await deploy(compiled, 'LicenseTerms.sol', 'LicenseTerms', admin, [await asset.getAddress(), 1]);
  const tUSD = await deploy(compiled, 'MintUSD.sol', 'TestUSD', admin, []);
  const engine = await deploy(compiled, 'RoyaltyEngine.sol', 'RoyaltyEngine', admin, [await tUSD.getAddress(), await asset.getAddress(), await terms.getAddress()]);
  const audit = await deploy(compiled, 'AuditCompliance.sol', 'AuditCompliance', admin, [await asset.getAddress()]);

  await (await asset.grantRole(await asset.CREATOR_ROLE(), await creator.getAddress())).wait();
  await (await terms.addValidator(await validator.getAddress())).wait();
  await (await engine.grantRole(await engine.REPORTER_ROLE(), await dsp.getAddress())).wait();
  await (await audit.grantRole(await audit.REPORTER_ROLE(), await dsp.getAddress())).wait();

  await (await asset.connect(creator).mintAsset('ipfs://cid', '0x' + 'a'.repeat(64))).wait();
  await (await terms.connect(creator).proposeTerms(1, 10n ** 15n, '0x' + 'b'.repeat(64))).wait();
  await (await terms.connect(validator).approveTerms(1)).wait();
  await (await terms.publishTerms(1)).wait();

  await (await tUSD.transfer(await dsp.getAddress(), ethers.parseEther('1000'))).wait();
  await (await tUSD.connect(dsp).approve(await engine.getAddress(), ethers.parseEther('500'))).wait();
  await (await engine.connect(dsp).fund(ethers.parseEther('200'))).wait();

  const creatorBefore = await tUSD.balanceOf(await creator.getAddress());
  await (await engine.connect(dsp).submitUsage(1, 100, '0x' + 'c'.repeat(64))).wait();
  const creatorAfter = await tUSD.balanceOf(await creator.getAddress());
  assert.equal((creatorAfter - creatorBefore).toString(), (100n * 10n ** 15n).toString(), 'creator payout mismatch');

  let duplicateRejected = false;
  try {
    await (await engine.connect(dsp).submitUsage(1, 100, '0x' + 'c'.repeat(64))).wait();
  } catch {
    duplicateRejected = true;
  }
  assert.equal(duplicateRejected, true, 'duplicate usage should be rejected');

  await (await terms.connect(creator).proposeTerms(1, 2n * 10n ** 15n, '0x' + 'd'.repeat(64))).wait();
  await (await terms.connect(validator).approveTerms(1)).wait();
  const [version, rate] = await terms.getTerms(1);
  assert.equal(version.toString(), '2', 'version should increment');
  assert.equal(rate.toString(), (2n * 10n ** 15n).toString(), 'rate should update');

  await (await audit.connect(dsp).recordAuditBundle(1, 1, 2, '0x' + '1'.repeat(64), '0x' + '2'.repeat(64), '0x' + '3'.repeat(64))).wait();
  await (await audit.markCompliant(1, true, 'ok')).wait();
  await (await audit.connect(creator).openDispute(1, '0x' + '4'.repeat(64))).wait();
  await (await audit.resolveDispute(1, true, '0x' + '5'.repeat(64))).wait();

  const bundle = await audit.getBundle(1);
  assert.equal(bundle[7], true, 'bundle should be compliant');
  assert.equal(bundle[8], true, 'bundle should be disputed');
  assert.equal(bundle[9], true, 'bundle should be resolved');
  assert.equal(bundle[10], true, 'decision should be upheld');

  console.log('PASS: deploy, role setup, mint, terms lifecycle, funding, payout, duplicate rejection, reproposal reapproval, audit flow');
})();
