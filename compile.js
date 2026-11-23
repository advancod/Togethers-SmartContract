const fs = require('fs')
const fsp = fs.promises
const solc = require('solc')
const path = require('path')

async function main() {
  // Load the contract source code
  const sourceCode = await fsp.readFile('Togethers.sol', 'utf8')
  // Compile the source code and retrieve the ABI and Bytecode
  const { abi, bytecode } = compile(sourceCode, 'Togethers')
  // Store the ABI and Bytecode into a JSON file
  const artifact = JSON.stringify({ abi, bytecode }, null, 2)
  await fsp.writeFile('Demo.json', artifact)
  console.log('Wrote Demo.json')
}

function findImports(importPath) {
  try {
    const resolved = path.resolve(__dirname, importPath)
    return { contents: fs.readFileSync(resolved, 'utf8') }
  } catch (err) {
    return { error: `File not found: ${importPath}` }
  }
}

function compile(sourceCode, contractName) {
  // Create the Solidity Compiler Standard Input and Output JSON
  const input = {
    language: 'Solidity',
    sources: { main: { content: sourceCode } },
    settings: { optimizer: { enabled: true, runs: 200 }, outputSelection: { '*': { '*': ['abi', 'evm.bytecode'] } } },
  }
  // Parse the compiler output to retrieve the ABI and Bytecode
  const output = JSON.parse(
    solc.compile(JSON.stringify(input), { import: findImports }),
  )

  if (output.errors) {
    const fatal = output.errors.filter((e) => e.severity === 'error')
    if (fatal.length > 0) {
      throw new Error(fatal.map((e) => e.formattedMessage).join('\n'))
    }
  }

  const artifact = output.contracts.main[contractName]
  if (!artifact) {
    const available = Object.keys(output.contracts?.main || {})
    throw new Error(
      `Contract "${contractName}" not found. Available: ${available.join(', ') || '(none)'}`,
    )
  }

  return {
    abi: artifact.abi,
    bytecode: artifact.evm.bytecode.object,
  }
}

main().catch((err) => {
  console.error(err.message || err)
  process.exit(1)
})
