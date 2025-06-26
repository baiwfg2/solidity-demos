async function main() {
    const [deployer] = await ethers.getSigners();
    
    // Grab the contract factory 
    const MyNFTFac = await ethers.getContractFactory("MandyNFT");
 
    console.log("ready to deploy, owner address:", deployer.address);
    // Start deployment, returning a promise that resolves to a contract object
    const myNFT = await MyNFTFac.deploy(deployer.address); // Pass the deployer's address as the initial owner
    
    // https://stackoverflow.com/questions/76912605/hardhat-deployed-is-not-a-function
    // await myNFT.deployed();
 
    await myNFT.waitForDeployment();
    console.log(`contract MandyNFT is deployed successfully at address ${myNFT.target}`)
    
    console.log("wait for confirmations")
    await myNFT.deploymentTransaction().wait(3)
    console.log("deploy confirmed")
 }
 
 main()
   .then(() => process.exit(0))
   .catch(error => {
     console.error(error);
     process.exit(1);
   });
 