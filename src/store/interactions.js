import { ethers } from 'ethers'

import {
  setProvider,
  setNetwork,
  setAccount
} from './reducers/provider'

import {
  setContracts,
  setSymbols,
  balancesLoaded
} from './reducers/tokens'

import {
  setContract,
  sharesLoaded,
  swapsLoaded,
  depositRequest,
  depositSuccess,
  depositFail,
  withdrawRequest,
  withdrawSuccess,
  withdrawFail,
  swapRequest,
  swapSuccess,
  swapFail
} from './reducers/amm'

import TOKEN_ABI from '../abis/Token.json';
import AMM_ABI from '../abis/AMM.json';
import config from '../config.json';

export const loadProvider = (dispatch) => {
  const provider = new ethers.BrowserProvider(window.ethereum)
  dispatch(setProvider(provider))

  return provider
}

export const loadNetwork = async (provider, dispatch) => {
  const network = await provider.getNetwork()
  dispatch(setNetwork(Number(network.chainId)))

  return Number(network.chainId)
}

export const loadAccount = async (dispatch) => {
  const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' })
  const account = ethers.getAddress(accounts[0])
  dispatch(setAccount(account))

  return account
}

// ------------------------------------------------------------------------------
// LOAD CONTRACTS
export const loadTokens = async (provider, chainId, dispatch) => {
  const dapp = new ethers.Contract(config[chainId].dapp.address, TOKEN_ABI, provider)
  const usd = new ethers.Contract(config[chainId].usd.address, TOKEN_ABI, provider)

  dispatch(setContracts([dapp, usd]))
  dispatch(setSymbols([await dapp.symbol(), await usd.symbol()]))
}

export const loadAMM = async (provider, chainId, dispatch) => {
  const amm = new ethers.Contract(config[chainId].amm.target, AMM_ABI, provider)

  dispatch(setContract(amm))

  return amm
}


// ------------------------------------------------------------------------------
// LOAD BALANCES & SHARES
export const loadBalances = async (amm, tokens, account, dispatch) => {
  const balance1 = await tokens[0].balanceOf(account)
  const balance2 = await tokens[1].balanceOf(account)

  dispatch(balancesLoaded([
    ethers.formatUnits(balance1.toString(), 'ether'),
    ethers.formatUnits(balance2.toString(), 'ether')
  ]))

  const shares = await amm.shares(account)
  dispatch(sharesLoaded(ethers.formatUnits(shares.toString(), 'ether')))
}


// ------------------------------------------------------------------------------
// ADD LIQUDITY
export const addLiquidity = async (provider, amm, tokens, amounts, dispatch) => {
  try {
    dispatch(depositRequest())

    const signer = await provider.getSigner()

    let transaction

    transaction = await tokens[0].connect(signer).approve(amm.target, amounts[0])
    await transaction.wait()

    transaction = await tokens[1].connect(signer).approve(amm.target, amounts[1])
    await transaction.wait()

    transaction = await amm.connect(signer).addLiquidity(amounts[0], amounts[1])
    await transaction.wait()

    dispatch(depositSuccess(transaction.hash))
  } catch (error) {
    dispatch(depositFail())
  }
}

// ------------------------------------------------------------------------------
// REMOVE LIQUDITY
export const removeLiquidity = async (provider, amm, shares, dispatch) => {
  try {
    dispatch(withdrawRequest())

    const signer = await provider.getSigner()

    let transaction = await amm.connect(signer).removeLiquidity(shares)
    await transaction.wait()

    dispatch(withdrawSuccess(transaction.hash))
  } catch (error) {
    dispatch(withdrawFail())
  }
}

// ------------------------------------------------------------------------------
// SWAP

export const swap = async (provider, amm, token, symbol, amount, dispatch) => {
  try {

    dispatch(swapRequest())

    let transaction

    const signer = await provider.getSigner()

    transaction = await token.connect(signer).approve(amm.target, amount)
    await transaction.wait()

    // Calculate expected output and apply 0.5% slippage tolerance
    let expectedOutput
    if (symbol === "DAPP") {
      expectedOutput = await amm.calculateToken1Swap(amount)
    } else {
      expectedOutput = await amm.calculateToken2Swap(amount)
    }
    const minAmountOut = expectedOutput * 995n / 1000n

    // Deadline: 20 minutes from the latest block
    const block = await provider.getBlock('latest')
    const deadline = block.timestamp + 1200

    if (symbol === "DAPP") {
      transaction = await amm.connect(signer).swapFirstToken(amount, minAmountOut, deadline)
    } else {
      transaction = await amm.connect(signer).swapSecondToken(amount, minAmountOut, deadline)
    }

    await transaction.wait()

    dispatch(swapSuccess(transaction.hash))

  } catch (error) {
    dispatch(swapFail())
  }
}


// ------------------------------------------------------------------------------
// LOAD ALL SWAPS

export const loadAllSwaps = async (provider, amm, dispatch) => {
  const block = await provider.getBlockNumber()

  const swapStream = await amm.queryFilter('Swap', 0, block)
  const swaps = swapStream.map(event => {
    return { hash: event.transactionHash, args: event.args }
  })

  dispatch(swapsLoaded(swaps))
}
