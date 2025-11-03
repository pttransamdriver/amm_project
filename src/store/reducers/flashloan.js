import { createSlice } from '@reduxjs/toolkit'

export const flashloan = createSlice({
  name: 'flashloan',
  initialState: {
    hubContract: null,
    strategyContracts: {},
    history: [],
    executing: {
      isExecuting: false,
      isSuccess: false,
      transactionHash: null
    },
    stats: {
      totalExecuted: 0,
      totalProfit: 0,
      successRate: 0
    }
  },
  reducers: {
    setHubContract: (state, action) => {
      state.hubContract = action.payload
    },
    setStrategyContract: (state, action) => {
      const { name, contract } = action.payload
      state.strategyContracts[name] = contract
    },
    flashloanRequest: (state) => {
      state.executing.isExecuting = true
      state.executing.isSuccess = false
      state.executing.transactionHash = null
    },
    flashloanSuccess: (state, action) => {
      state.executing.isExecuting = false
      state.executing.isSuccess = true
      state.executing.transactionHash = action.payload.hash
      
      state.history.push({
        timestamp: Date.now(),
        provider: action.payload.provider,
        token: action.payload.token,
        amount: action.payload.amount,
        profit: action.payload.profit,
        strategy: action.payload.strategy,
        hash: action.payload.hash
      })
      
      state.stats.totalExecuted += 1
      state.stats.totalProfit += parseFloat(action.payload.profit || 0)
      state.stats.successRate = (state.stats.totalExecuted > 0) 
        ? (state.history.filter(h => h.profit > 0).length / state.stats.totalExecuted) * 100 
        : 0
    },
    flashloanFail: (state) => {
      state.executing.isExecuting = false
      state.executing.isSuccess = false
      state.executing.transactionHash = null
      
      state.stats.totalExecuted += 1
      state.stats.successRate = (state.stats.totalExecuted > 0) 
        ? (state.history.filter(h => h.profit > 0).length / state.stats.totalExecuted) * 100 
        : 0
    },
    historyLoaded: (state, action) => {
      state.history = action.payload
    }
  }
})

export const {
  setHubContract,
  setStrategyContract,
  flashloanRequest,
  flashloanSuccess,
  flashloanFail,
  historyLoaded
} = flashloan.actions

export default flashloan.reducer

