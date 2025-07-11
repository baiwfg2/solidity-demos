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

    const clearTx = await myVrf.clearResult(owner)
    await clearTx.wait()

    const rollTx = await myVrf.rollDice(owner)
    const rollReceipt = await rollTx.wait()
    console.log(`rollDice confirmed: ${rollTx.hash}`)
    
    // fetch requestId from event log
    const diceRolledEvent = rollReceipt.logs.find(log => {
        try {
            const parsed = myVrf.interface.parseLog(log)
            return parsed.name === 'DiceRolled'
        } catch {
            return false
        }
    })
    
    if (diceRolledEvent) {
        const parsed = myVrf.interface.parseLog(diceRolledEvent)
        const reqId = parsed.args[0]
        console.log(`reqId is 0x${reqId.toString(16)}`)
        
        let attempts = 0
        const maxAttempts = 60

        /*
            cursor advices that only using polling in loop can get the results.
            house() is pure-read op, so it can't be waited, whereas clearResult,rollDice is write op, so need to be waited.
            VRF fulfil is not initiated by my VRFD20 contract, so we don't know when it completes
        */
        
        while (attempts < maxAttempts) {
            try {
                const houseGot = await myVrf.house(owner)
                console.log(`🎲 Random Result: ${houseGot}`)
                break
            } catch (error) {
                if (error.message.includes("Roll in progress")) {
                    console.log(`IN RPOGRESS ... (${attempts + 1}/${maxAttempts})`)
                    await new Promise(resolve => setTimeout(resolve, 5000)) // 等待5秒
                    attempts++
                } else {
                    console.error(`Other error: ${error.message}`)
                    break
                }
            }
        }
        
        if (attempts >= maxAttempts) {
            console.log("getting house timedout")
        }
    } else {
        console.log("DiceRolled event not found")
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

/*
while { myVrf.house() } version:

$ node scripts/query-vrf.js 0x4385a211c3119c2a2Fa0bB1805103c08Ac901472
[dotenv@17.2.0] injecting env (6) from .env (tip: ⚙  
️  write to custom object with { processEnv: myObjec 
t })
owner is 0xA4a8dcE9F35C75f57dF0449B0543Cd767BeF6305  
rollDice confirmed: 0xd5b14aeb6e07fef2e00e01f3510c130b05aa44d6dde8b6b3be473584eac17ccc
reqId is 0xb2cd2086083da030583b2fa565dad4a47c482dacd43f04821537c8a18a0a2861
IN RPOGRESS ... (1/60)
IN RPOGRESS ... (2/60)
IN RPOGRESS ... (3/60)
IN RPOGRESS ... (4/60)
IN RPOGRESS ... (5/60)
IN RPOGRESS ... (6/60)
IN RPOGRESS ... (7/60)
IN RPOGRESS ... (8/60)
IN RPOGRESS ... (9/60)
IN RPOGRESS ... (10/60)
IN RPOGRESS ... (11/60)
� Random Result: Clegane
*/