
const colors = require("../scripts/utils");

/**
 * @param {Object} hre - Hardhat runtime environment
 * @param {Function} hre.getNamedAccounts - Function to get named accounts
 * @param {Object} hre.deployments - Deployments object
 */
module.exports = async({getNamedAccounts, deployments}) => {
    const {firstAccount} = await getNamedAccounts()
    const {deploy, log} = deployments
    
    log(colors.blue("Deploying the nft contract"))
    await deploy("MyNFT", {
        contract: "MyNFT",
        from: firstAccount,
        log: true,
        args: ["MyNFT", "MNT"]
    })
    log("MyToken is deployed!")
}

module.exports.tags = ["all", "srcchain"]