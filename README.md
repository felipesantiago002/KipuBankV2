# KipuBankV2
### Mejoras realizadas
1. Control de Acceso
   - Solo el admin (deployer) puede configurar decimales de tokens y consultar balances de cualquier usuario.  
   - Se utiliza AccessControl de OpenZeppelin para roles y permisos.

2. Soporte Multi-Token  
   - Se pueden depositar y retirar ETH y ERC-20.  
   - ERC-20 se manejan mediante SafeERC20 para transferencias seguras.

3. Contabilidad Interna Uniforme  
   - Todos los tokens se convierten a una unidad interna de 6 decimales internalDecimals tipo USDC.  
   - Esto permite comparaciones consistentes, por ejemplo, para límites de retiro.
     
4. Oráculo ETH/USD  
   - El límite máximo del banco bankCap se aplica solo a ETH.  
   - Se utiliza Chainlink ETH/USD para convertir depósitos de ETH a USD internos.

## Instrucciones de Despliegue

1)Abrir Remix IDE
2)Seleccionar compilador: 0.8.26
3)Importar tu contrato KipuBank_V3.sol
4)Asegurarse que los imports de OpenZeppelin estén disponibles o usar versión flattened del contrato.
5)Seleccionar Deploy & Run Transactions
6)Elegir environment (Injected Web3 para Metamask en mi caso)
Constructor del contrato requiere 3 parámetros:
    bankCapUSD	Límite máximo del banco en USD internos
    maxWithdrawInternal	Límite máximo de retiro por operación en internal decimals
    priceFeedETHUSD la address de donde sacara el oraculo la informacion de precio de ETH

## Decisiones de Diseño

--> Primeramente, tuve inconvenientes para determinar los decimales de cada token ERC20, por lo cual opte por la opcion donde
el admin debe estipular manualmente que decimales tiene cada token aceptada. Me ahorro simplicidad en el codigo pero pierdo flexibilidad 
a la hora de aceptar CUALQUIER token ERC20 sin tener que estipularlas manualmente.
--> Tambien elegi herramientas de OpenZepellin para realizar controles de acceso y transferencias seguras de ERC20, pero como tradeoff tengo 
mucho acople con dichas herramientas ya que si alguna de ellas deja de funcionar o tiene vulnerabilidades de seguridad, mi contrato se ve 
gravemente afectado.


