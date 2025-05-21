import { useSelector, useDispatch } from 'react-redux'
import { ethers } from 'ethers'
import { useEffect } from 'react'
import { loading } from './Loading'
import { loadAllSwaps } from '../store/interactions'

const Charts = () => {
  const provider = useSelector(state => state.provider.connection)
  const tokens = useSelector(state => state.tokens.contracts)
  const symbols = useSelector(state => state.tokens.symbols)
  const amm = useSelector(state => state.amm.contract)
  const dispatch = useDispatch()

  useEffect (() => {
    loadAllSwaps(provider, amm, dispatch)=
  } [],)

  return (
    <div>Charts</div>
  );
}

export default Charts;