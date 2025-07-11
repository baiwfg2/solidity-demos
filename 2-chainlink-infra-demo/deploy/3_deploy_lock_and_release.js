//const {developmentChains, networkConfig} = require("../helper-hardhat-config")

const colors = require("../scripts/utils")

module.exports = async({getNamedAccounts, deployments}) => {
    const { firstAccount } = await getNamedAccounts()
    const { deploy, log } = deployments

    // get parameters for constructor
    let sourceChainRouter
    let linkToken
    let nftAddr
    //if(developmentChains.includes(network.name)) {
        const ccipSimulatorDeployment = await deployments.get("CCIPLocalSimulator")
        const ccipSimulator = await ethers.getContractAt("CCIPLocalSimulator", ccipSimulatorDeployment.address)
        const ccipSimulatorConfig = await ccipSimulator.configuration()
        sourceChainRouter = ccipSimulatorConfig.sourceRouter_
        linkToken = ccipSimulatorConfig.linkToken_       
        log(`local environment: sourcechain router: ${sourceChainRouter}, link token: ${linkToken}`) 
    // } else {
    //     // get router and linktoken based on network
    //     sourceChainRouter = networkConfig[network.config.chainId].router
    //     linkToken = networkConfig[network.config.chainId].linkToken
    //     log(`non local environment: sourcechain router: ${sourceChainRouter}, link token: ${linkToken}`)
    // }
    
    const nftDeployment = await deployments.get("MyNFT")
    nftAddr = nftDeployment.address
    log(`NFT address: ${nftAddr}`)

    log(colors.blue("deploying the lockAndRelease contract"))
    await deploy("NFTPoolLockAndRelease", {
        contract: "NFTPoolLockAndRelease",
        from: firstAccount,
        log: true,
        args: [sourceChainRouter, linkToken, nftAddr]
    })
    log("lockAndRelease deployed")
}

module.exports.tags = ["all", "srcchain"]