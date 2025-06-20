import { useCurrentAccount, useSuiClientContext } from "@mysten/dapp-kit";
import { Container, Flex, Heading, Text } from "@radix-ui/themes";
// import { OwnedObjects } from "./OwnedObjects";

export function WalletStatus() {
  const account = useCurrentAccount();
  const { network } = useSuiClientContext();

  return (
    <Container my="2">
      <Heading mb="2">Wallet Status</Heading>
      <Text>Network: {network ? (
        <p>当前连接网络: <strong>{network}</strong></p>
      ) : (
        <p>钱包未连接或无法获取网络信息。</p>
      )}</Text>
      {account ? (
        <Flex direction="column">
          <Text>Wallet connected</Text>
          <Text>Address: {account.address}</Text>
        </Flex>
      ) : (
        <Text>Wallet not connected</Text>
      )}
      {/* <OwnedObjects /> */}
    </Container>
  );
}
