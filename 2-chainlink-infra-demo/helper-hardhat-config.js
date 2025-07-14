developmentChains = ["hardhat", "localhost"]
const networkConfig = {
    11155111: {
        name: "sepolia",
        router: "0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59",
        linkToken: "0x779877A7B0D9E8603169DdbD7836e478b4624789",
        companionChainSelector: "16281711391670634445"
    },
    80002: {
        name: "amoy",
        router: "0x9C32fCB86BF0f4a1A8921a9Fe46de3198bb884B2",
        linkToken: "0x0Fd9e8d3aF1aaee056EB9e802c3A762a667b1904",
        companionChainSelector: "16015286601757825753"
    },
    43113: {
        name: "fuji",
        router: "0xF694E193200268f9a4868e4Aa017A0118C9a8177",
        linkToken: "0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846",
        chainSelector: "14767482510784806043",
        functionRouter: "0xA9d587a00A31A52Ed70D6026794a8FC5E2F5dCb0"
    }

}
module.exports ={
    developmentChains,
    networkConfig
}