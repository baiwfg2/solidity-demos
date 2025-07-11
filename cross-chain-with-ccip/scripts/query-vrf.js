require('dotenv').config();
const ethers = require('ethers');

// Get Alchemy API Key
const apiKey = process.env.ALCHEMY_API_KEY;

// Define an Alchemy Provider
const provider = new ethers.AlchemyProvider('sepolia', apiKey)

// Get contract ABI file
const contract = require("../artifacts/contracts/VRFD20.sol/VRFD20.json");

// Create a signer
const privateKey = process.env.PRIVATE_KEY1
const signer = new ethers.Wallet(privateKey, provider)

// Get contract ABI and address
const abi = contract.abi
const contractAddress = process.argv[2]

// Create a contract instance
const myVrf = new ethers.Contract(contractAddress, abi, signer)

const main = async() => {
    let owner = await myVrf.owner()
    console.log(`owner is ${owner}`)

    let reqId = await myVrf.rollDice(owner)
    console.log(`reqId is ${reqId}`)

    let houseGot = await myVrf.house(owner)
    console.log(`reqId is ${houseGot}`)
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
