const { Web3 } = require('web3')

// Loading the contract ABI and Bytecode
// (the results of a previous compilation step)
const fs = require('fs')
const { abi, bytecode } = JSON.parse(fs.readFileSync('Demo.json'))

async function main() {
  // Configuring the connection to an Ethereum node
  const network = process.env.ETHEREUM_NETWORK
  const web3 = new Web3(
    new Web3.providers.HttpProvider(`https://${network}.infura.io/v3/${process.env.INFURA_API_KEY}`)
  )
  // Creating a signing account from a private key
  const signer = web3.eth.accounts.privateKeyToAccount(
    process.env.SIGNER_PRIVATE_KEY.startsWith('0x') ? process.env.SIGNER_PRIVATE_KEY : '0x' + process.env.SIGNER_PRIVATE_KEY
  )
  web3.eth.accounts.wallet.add(signer)

  // Using the signing account to deploy the contract
  const contract = new web3.eth.Contract(abi)
  contract.options.data = bytecode
  const deployTx = contract.deploy()
  // Depuis Glamsterdam (Sepolia, oct. 2026), stocker le code coûte 1530 gas/octet (EIP-8037).
  // L'estimation est juste à la limite : on ajoute 30 % de marge.
  const estimate = await deployTx.estimateGas()
  const gas = (BigInt(estimate) * 13n) / 10n
  console.log(`Gas estimé : ${estimate}, limite utilisée : ${gas}`)
  const deployedContract = await deployTx
    .send({
      from: signer.address,
      gas,
    })
    .once('transactionHash', txhash => {
      console.log(`Mining deployment transaction ...`)
      console.log(`https://${network}.etherscan.io/tx/${txhash}`)
    })
  // The contract is now deployed on chain!
  console.log(`Contract deployed at ${deployedContract.options.address}`)
  console.log(
    `Add DEMO_CONTRACT to the .env file to store the contract address: ${deployedContract.options.address}`
  )
}

require('dotenv').config()
main()