import { ethers } from "hardhat";
import { Contract } from "ethers"


import farmAbi from "./abis/HashStratDAOTokenFarm.json"

const usdcAddress = '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174'

// HashStratDAO Token deployed at address: 0x2223Ad393d666Eb26422d1f7b33A6947BFc2eaCa
// HashStratDAOTokenFarm deployed at address: 0x130e249DA0B90378eB07845217d6bB832E16f038
// HashStratGovernance deployed at address: 0xD9CF1D8c68f1986D20CCffe2268dd4Cb7F518f4B


main().catch((error) => {
	console.error(error);
	process.exitCode = 1;
});


async function main() {
	const farmAddress = await depolyHashStratDAOTokenAndFarm("HashStrat DAO Token", "HST", 18)
	await addLPTokensToFarm(farmAddress)
	await deployGovernance(usdcAddress)
}



const depolyHashStratDAOTokenAndFarm = async (name: string, symbol: string, decimals: number) => {

	///////  Deploy HashStratDAOToken 

	console.log("Starting deployment of HashStratDAOToken: ", name, "on POLYGON")
	const HashStratDAO = await ethers.getContractFactory("HashStratDAOToken");

	const supply = ethers.utils.parseEther('1000000.0');   // 1M tokens
	const hashStratDAO = await HashStratDAO.deploy(name, symbol, decimals, supply)
	await hashStratDAO.deployed()

	console.log("HashStratDAOToken deployed at address:", hashStratDAO.address);
	console.log("HashStratDAOToken totalSupply::",  ethers.utils.formatEther( await hashStratDAO.totalSupply()) ) ;


	/////// Deploy HashStratDAOTokenFarm

	console.log("Starting deployment of HashStratDAOTokenFarm: ", name, "on POLYGON")
	const HashStratDAOTokenFarm = await ethers.getContractFactory("HashStratDAOTokenFarm");

  	const hashStratDAOTokenFarm = await HashStratDAOTokenFarm.deploy(hashStratDAO.address);
	await hashStratDAOTokenFarm.deployed();
	console.log("HashStratDAOTokenFarm deployed at address:", hashStratDAOTokenFarm.address);


	// Transfer DAO Token supply to FARM
	await hashStratDAO.transfer(hashStratDAOTokenFarm.address, supply)
	console.log("transferred DAO tokens to HashStratDAOTokenFarm")

	// Add reward phases to Farm
	await hashStratDAOTokenFarm.addRewardPeriods()
	console.log("rewards periods created: ", (await hashStratDAOTokenFarm.rewardPeriodsCount()).toString() )

	return hashStratDAOTokenFarm.address
}


const deployGovernance = async (depositTokenAddress: string) => {

	///////  Deploy Governance 
	console.log("Starting deployment of HashStratGovernance: on POLYGON")
	const HashStratGovernance = await ethers.getContractFactory("HashStratGovernance");
	const hashStratGovernance = await HashStratGovernance.deploy(depositTokenAddress)
	await hashStratGovernance.deployed()

	console.log("HashStratGovernance deployed at address:", hashStratGovernance.address);
}


const addLPTokensToFarm = async (farmAddress: string) => {
	
	const hashStratDAOTokenFarm = new Contract(farmAddress, farmAbi, ethers.provider)
	console.log("HashStratDAOTokenFarm - addLPTokensToFarm at address:: ", hashStratDAOTokenFarm.address)

	const [owner] = await ethers.getSigners();
	const lptokens = getPoolLPTokenAddreses()

	
	lptokens.forEach( async (addr, idx) =>  {
 
		/// add addr a one by one
		// if (idx !== 0) return

		const block = await ethers.provider.getBlockNumber()
		console.log( "Added LP to farm: ", idx, "address: ", addr, "block: ", block)

		await hashStratDAOTokenFarm.connect(owner).addLPToken(addr)
		let added = false
		do {
			await delay(5000);
			const newBlock = await ethers.provider.getBlockNumber()
			const lpaddrs = await hashStratDAOTokenFarm.getLPTokens()
			console.log("block", newBlock, "adding: ", addr, ", lpaddrs: ", lpaddrs)
			added = lpaddrs.some( (element : string) => {
				return element.toLowerCase() === addr.toLowerCase();
			})
			
			console.log("block", newBlock, addr, "added: ", added, "...")

		} while (!added)
	
	})

	console.log("HashStratDAOTokenFarm getLPTokens:: ", await hashStratDAOTokenFarm.getLPTokens() )
}


const getPoolLPTokenAddreses = () : string[] => {
	return Object.keys(polygonPools).map(poolId => {
		const poolInfo = polygonPools[poolId as keyof typeof polygonPools ]
		return poolInfo["pool_lp"] as string
	});
}


const delay = async (ms: number) : Promise<any> => {
    return new Promise( resolve => setTimeout(resolve, ms) );
}



const polygonPools = {
	"index01": {
		"pool": "0x371B94a526A0aA76A2fa30b6Dcaf871c4449edCA",
		"pool_lp": "0x6dB28fA2325E9Fa4A2Ed24120FC89D8849Ec6596"
	},
	"index02": {
		"pool": "0x4244fA37A32231Bd6d35A9f81e43fB0a8b25AA55",
		"pool_lp": "0x7851086E8A77940067B22540a9661Fe7D716b9FB"
	},
	"index03": {
		"pool": "0x826c28BB9d308E46D97E12ef95bDC5653f796bdC",
		"pool_lp": "0x5A832F1C84E1365ea52897B3463CA4FECFf2D4eE"
	},

	"pool01": {
		"pool": "0x7b8b3fc7563689546217cFa1cfCEC2541077170f",
		"pool_lp": "0x2EbF538B3E0F556621cc33AB5799b8eF089b2D8C",
		"strategy": "0x6aa3D1CB02a20cff58B402852FD5e8666f9AD4bd",
		"price_feed": "0xc907E116054Ad103354f2D350FD2514433D57F6f"
	},
	"pool02": {
		"pool": "0x62464FfFAe0120E662169922730d4e96b7A59700",
		"pool_lp": "0x26b80F5970bC835751e2Aabf4e9Bc5B873713f17",
		"strategy": "0xca5B24b63D929Ddd5856866BdCec17cf13bDB359",
		"price_feed": "0xF9680D99D6C9589e2a93a78A04A279e509205945"
	},
	"pool03": {
		"pool": "0xc60CE76892138d9E0cE722eB552C5d8DE70375a5",
		"pool_lp": "0xe62A17b61e4E309c491F1BD26bA7BfE9e463610e",
		"strategy": "0x46cfDDc7ab8348b44b4a0447F0e5077188c4ff14",
		"price_feed": "0xc907E116054Ad103354f2D350FD2514433D57F6f"
	},
	"pool04": {
		"pool": "0x82314313829B7AF502f9D60a4f215F6b6aFbBE4B",
		"pool_lp": "0xA9085698662029Ef6C21Bbb23a81d3eB55898926",
		"strategy": "0x02CF4916Dd9f4bB329AbE5e043569E586fE006E4",
		"price_feed": "0xF9680D99D6C9589e2a93a78A04A279e509205945"
	},
	"pool05": {
		"pool": "0x742953942d6A3B005e28a451a0D613337D7767b2",
		"pool_lp": "0x7EB471C4033dd8c25881e9c02ddCE0C382AE8Adb",
		"strategy": "0x7F7a40fa461931f3aecD183f8B56b2782483B04B",
		"price_feed": "0xc907E116054Ad103354f2D350FD2514433D57F6f"
	},
	"pool06": {
		"pool": "0x949e118A42D15Aa09d9875AcD22B87BB0E92EB40",
		"pool_lp": "0x74243293f6642294d3cc94a9C633Ae943d557Cd3",
		"strategy": "0x26311040c72f08EF1440B784117eb96EA20A2412",
		"price_feed": "0xF9680D99D6C9589e2a93a78A04A279e509205945"
	},
  }

