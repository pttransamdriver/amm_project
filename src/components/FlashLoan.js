import { useState, useEffect } from 'react';
import { useSelector, useDispatch } from 'react-redux';
import Card from 'react-bootstrap/Card';
import Form from 'react-bootstrap/Form';
import InputGroup from 'react-bootstrap/InputGroup';
import Dropdown from 'react-bootstrap/Dropdown';
import DropdownButton from 'react-bootstrap/DropdownButton';
import Button from 'react-bootstrap/Button';
import Row from 'react-bootstrap/Row';
import Spinner from 'react-bootstrap/Spinner';
import { ethers } from 'ethers';

const FlashLoan = () => {
  const [provider, setProvider] = useState('CUSTOM_AMM');
  const [token, setToken] = useState('DAPP');
  const [amount, setAmount] = useState(0);
  const [strategy, setStrategy] = useState('SIMPLE_ARBITRAGE');
  const [estimatedProfit, setEstimatedProfit] = useState(0);
  const [maxLoan, setMaxLoan] = useState(0);
  const [fee, setFee] = useState(0);
  const [showAlert, setShowAlert] = useState(false);

  const account = useSelector(state => state.provider.account);
  const tokens = useSelector(state => state.tokens.contracts);
  const symbols = useSelector(state => state.tokens.symbols);
  const balances = useSelector(state => state.tokens.balances);
  const amm = useSelector(state => state.amm.contract);
  const isExecuting = useSelector(state => state.flashloan?.isExecuting);

  const dispatch = useDispatch();

  const providerOptions = [
    { value: 'CUSTOM_AMM', label: 'Custom AMM (0.09% fee)', fee: 0.09 },
    { value: 'AAVE_V3', label: 'Aave V3 (0.09% fee)', fee: 0.09 },
    { value: 'UNISWAP_V3', label: 'Uniswap V3 (varies)', fee: 0.05 },
    { value: 'BALANCER_V2', label: 'Balancer V2 (0% fee)', fee: 0 }
  ];

  const strategyOptions = [
    { value: 'SIMPLE_ARBITRAGE', label: 'Simple Arbitrage (2-DEX)' },
    { value: 'TRIANGULAR_ARBITRAGE', label: 'Triangular Arbitrage (3-token)' },
    { value: 'CUSTOM', label: 'Custom Strategy' }
  ];

  useEffect(() => {
    if (amm && amount > 0) {
      updateMaxLoan();
      calculateFee();
    }
  }, [provider, token, amount, amm]);

  const updateMaxLoan = async () => {
    if (!amm) return;

    try {
      let max;
      if (provider === 'CUSTOM_AMM') {
        if (token === 'DAPP') {
          max = await amm.getMaxFlashLoanFirstToken();
        } else {
          max = await amm.getMaxFlashLoanSecondToken();
        }
        setMaxLoan(ethers.formatEther(max));
      } else {
        setMaxLoan('Check provider');
      }
    } catch (error) {
      console.error('Error fetching max loan:', error);
    }
  };

  const calculateFee = () => {
    const selectedProvider = providerOptions.find(p => p.value === provider);
    if (selectedProvider && amount > 0) {
      const feeAmount = (parseFloat(amount) * selectedProvider.fee) / 100;
      setFee(feeAmount.toFixed(6));
    }
  };

  const amountHandler = async (e) => {
    setAmount(e.target.value);
    
    // TODO: Call strategy contract to estimate profit
    // For now, show placeholder
    if (e.target.value > 0) {
      setEstimatedProfit((parseFloat(e.target.value) * 0.5).toFixed(4));
    } else {
      setEstimatedProfit(0);
    }
  };

  const executeHandler = async (e) => {
    e.preventDefault();
    setShowAlert(false);

    if (amount <= 0) {
      window.alert('Please enter a valid amount');
      return;
    }

    if (parseFloat(amount) > parseFloat(maxLoan)) {
      window.alert(`Amount exceeds maximum available: ${maxLoan}`);
      return;
    }

    try {
      // TODO: Implement flashloan execution
      // const _amount = ethers.parseUnits(amount, 'ether');
      // await executeFlashLoan(provider, amm, flashLoanHub, token, _amount, strategy, dispatch);
      
      console.log('Executing flashloan:', {
        provider,
        token,
        amount,
        strategy,
        fee
      });

      setShowAlert(true);
    } catch (error) {
      console.error('Flashloan execution failed:', error);
      window.alert('Flashloan execution failed. See console for details.');
    }
  };

  return (
    <div>
      <Card style={{ maxWidth: '450px' }} className='mx-auto px-4'>
        <Form onSubmit={executeHandler} style={{ maxWidth: '450px', margin: '50px auto' }}>
          
          <Row className='my-3'>
            <div className='d-flex justify-content-between'>
              <Form.Label><strong>FlashLoan Provider:</strong></Form.Label>
            </div>
            <DropdownButton
              variant="outline-secondary"
              title={providerOptions.find(p => p.value === provider)?.label || 'Select Provider'}
            >
              {providerOptions.map((option) => (
                <Dropdown.Item
                  key={option.value}
                  onClick={() => setProvider(option.value)}
                >
                  {option.label}
                </Dropdown.Item>
              ))}
            </DropdownButton>
          </Row>

          <Row className='my-3'>
            <div className='d-flex justify-content-between'>
              <Form.Label><strong>Token:</strong></Form.Label>
              <Form.Text muted>
                Max Available: {maxLoan}
              </Form.Text>
            </div>
            <DropdownButton
              variant="outline-secondary"
              title={token}
            >
              {symbols && symbols.map((symbol, idx) => (
                <Dropdown.Item
                  key={idx}
                  onClick={() => setToken(symbol)}
                >
                  {symbol}
                </Dropdown.Item>
              ))}
            </DropdownButton>
          </Row>

          <Row className='my-3'>
            <Form.Label><strong>Amount:</strong></Form.Label>
            <InputGroup>
              <Form.Control
                type="number"
                placeholder="0.0"
                step="any"
                onChange={amountHandler}
                disabled={!provider}
              />
              <InputGroup.Text style={{ width: "100px" }} className="justify-content-center">
                {token}
              </InputGroup.Text>
            </InputGroup>
            <Form.Text muted>
              Fee: {fee} {token} ({providerOptions.find(p => p.value === provider)?.fee}%)
            </Form.Text>
          </Row>

          <Row className='my-3'>
            <div className='d-flex justify-content-between'>
              <Form.Label><strong>Strategy:</strong></Form.Label>
            </div>
            <DropdownButton
              variant="outline-secondary"
              title={strategyOptions.find(s => s.value === strategy)?.label || 'Select Strategy'}
            >
              {strategyOptions.map((option) => (
                <Dropdown.Item
                  key={option.value}
                  onClick={() => setStrategy(option.value)}
                >
                  {option.label}
                </Dropdown.Item>
              ))}
            </DropdownButton>
          </Row>

          <Row className='my-3'>
            <div className='d-flex justify-content-between'>
              <Form.Label><strong>Estimated Profit:</strong></Form.Label>
              <Form.Text className={estimatedProfit > 0 ? 'text-success' : 'text-danger'}>
                {estimatedProfit > 0 ? '+' : ''}{estimatedProfit} {token}
              </Form.Text>
            </div>
          </Row>

          <Row className='my-3'>
            {isExecuting ? (
              <Spinner animation="border" style={{ display: 'block', margin: '0 auto' }} />
            ) : (
              <Button type='submit' disabled={!provider || !strategy || amount <= 0}>
                Execute FlashLoan
              </Button>
            )}
          </Row>

        </Form>
      </Card>

      {showAlert && (
        <div className="alert alert-success alert-dismissible fade show mt-3" role="alert" style={{ maxWidth: '450px', margin: '0 auto' }}>
          <strong>FlashLoan Executed!</strong> Check your wallet for results.
          <button type="button" className="btn-close" onClick={() => setShowAlert(false)}></button>
        </div>
      )}

      <Card style={{ maxWidth: '450px' }} className='mx-auto px-4 mt-4'>
        <Card.Body>
          <Card.Title>How FlashLoans Work</Card.Title>
          <Card.Text>
            <ol>
              <li>Borrow tokens instantly (no collateral)</li>
              <li>Execute your strategy (arbitrage, etc.)</li>
              <li>Repay loan + fee in same transaction</li>
              <li>Keep the profit!</li>
            </ol>
            <strong>Note:</strong> If you can't repay, the entire transaction reverts.
          </Card.Text>
        </Card.Body>
      </Card>
    </div>
  );
};

export default FlashLoan;

