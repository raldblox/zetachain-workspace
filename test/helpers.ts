import { BigNumber } from "@ethersproject/bignumber";
import { ethers } from "hardhat";

export const encodeParams = (dataTypes: any[], data: any[]) => {
  const abiCoder = ethers.utils.defaultAbiCoder;
  return abiCoder.encode(dataTypes, data);
};

export const getSwapParams = (
  destination: string,
  destinationToken: string,
  minOutput: BigNumber
) => {
  const paddedDestination = ethers.utils.hexlify(
    ethers.utils.zeroPad(destination, 32)
  );
  const params = encodeParams(
    ["address", "bytes32", "uint256"],
    [destinationToken, paddedDestination, minOutput]
  );

  return params;
};