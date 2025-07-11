const colors = require("../scripts/utils")

module.exports = async({getNamedAccounts, deployments}) => {
    const {firstAccount} = await getNamedAccounts()
    const {deploy, log} = deployments
    
    log(colors.blue("Deploying the wnft contract"))
    await deploy("WrappedNFT", {
        contract: "WrappedNFT",
        from: firstAccount,
        log: true,
        args: ["WrappedNFT", "WNT"]
    })
    log("MyNFT is deployed!")
}

module.exports.tags = ["all", "destchain"]