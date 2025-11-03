import { configureStore } from '@reduxjs/toolkit'

import provider from './reducers/provider'
import tokens from './reducers/tokens'
import amm from './reducers/amm'
import flashloan from './reducers/flashloan'

export const store = configureStore({
  reducer: {
    provider,
    tokens,
    amm,
    flashloan
  },
  middleware: getDefaultMiddleware =>
    getDefaultMiddleware({
      serializableCheck: false
    })
})
