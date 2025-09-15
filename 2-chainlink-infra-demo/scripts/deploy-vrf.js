const { ethers } = require("hardhat");
require('dotenv').config();

async function main() {
    const vrfFactory = await ethers.getContractFactory("VRFD20");

    // let subId = BigInt(process.argv[2]);
    let subId = BigInt(process.env.CHAINLINK_VRF_SUBID);
    const vrf = await vrfFactory.deploy(subId);
    await vrf.waitForDeployment();
    let owner = await vrf.owner();
    console.log(`VRF contract deployed, at ${vrf.target}, owner:${owner}`);
    // register address as consumer of chainlink subscription
}

main().then().catch((error) => {
    console.error(error)
    process.exit(1)
})

/*

node scripts/deploy-vrf.js
✅ 可以执行
✅ 部署到默认的 Hardhat 本地网络
❌ 无法使用 hardhat.config.js 中配置的网络（如 sepolia、amoy）
❌ 无法使用配置的账户和私钥

npx hardhat run scripts/deploy-vrf.js
✅ 可以执行
✅ 可以使用配置的网络（通过 --network 参数）
✅ 使用配置的账户和私钥
✅ 完整的 Hardhat 环境支持
*/