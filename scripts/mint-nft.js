require('dotenv').config();
const ethers = require('ethers');

// Get Alchemy API Key
const apiKey = process.env.ALCHEMY_API_KEY;

// Define an Alchemy Provider
const provider = new ethers.AlchemyProvider('sepolia', apiKey)

// Get contract ABI file
const contract = require("../artifacts/contracts/MyNFT.sol/MandyNFT.json");

// Create a signer
const privateKey = process.env.PRIVATE_KEY1
const signer = new ethers.Wallet(privateKey, provider)

// Get contract ABI and address
const abi = contract.abi
const contractAddress = '0x005a17326DcE17a742684775f58683e56F306fba'

// Create a contract instance
const myNftContract = new ethers.Contract(contractAddress, abi, signer)

// Get the NFT Metadata IPFS URL
const tokenUri = "https://gateway.pinata.cloud/ipfs/bafkreidcwbumastrnqepi3cwellowwos3tbcel6ajmfqupm2fqfghwd3ma"

// Call mintNFT function
const mintNFT = async () => {
    let nftTxn = await myNftContract.mintNFT(signer.address, tokenUri)
    await nftTxn.wait()
    console.log(`NFT Minted to ${signer.address}. Check it out at: https://sepolia.etherscan.io/tx/${nftTxn.hash}`)
}

mintNFT()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
