require('dotenv').config();
const ethers = require('ethers');

// Get Alchemy API Key
const apiKey = process.env.ALCHEMY_API_KEY;

// not support fuji network name
// const provider = new ethers.AlchemyProvider("avalanche-fuji", apiKey)
const provider = new ethers.JsonRpcProvider(process.env.FUJI_RPC_URL);

// Get contract ABI file
const contract = require("../artifacts/contracts/RWA-estate-tokenize/RealEstateToken.sol/RealEstateToken.json");

// Create a signer
const privateKey = process.env.PRIVATE_KEY1
const signer = new ethers.Wallet(privateKey, provider)

// Get contract ABI and address
const abi = contract.abi
const contractAddress = process.argv[2]

// Create a contract instance
const reToken = new ethers.Contract(contractAddress, abi, signer)

const main = async() => {
    let owner = await reToken.owner()
    console.log(`owner is ${owner}`)

    const totalSupply = await reToken.totalSupply()
    console.log(`supply: ${totalSupply}`)
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

    
/*

This file is not complete, just as an exmaple similar to query-vrf.js
The action of setting Issuer can be done via tasks/rwa-3-setIssuer.js

$ node scripts/rwa-3_set-issuer.js 0x9C406980106d46c21b7953Fd3A5279fE62FF80ea
[dotenv@17.2.0] injecting env (7) from .env (tip: ⚙️  enable debug logging   
with { debug: true })
owner is 0xA4a8dcE9F35C75f57dF0449B0543Cd767BeF6305
supply: 0

*/