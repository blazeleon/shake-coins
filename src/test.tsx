import React from 'react';
import { fromBase64 } from '@mysten/bcs';
import { getFullnodeUrl, SuiClient ,RawData} from '@mysten/sui/client';

export function MyObject() {
    const suiClient = new SuiClient({ url: getFullnodeUrl('testnet') });
    suiClient.getObject({
        id: '0x19e76ca504c5a5fa5e214a45fca6c058171ba333f6da897b82731094504d5ab9',
        options: {
            showContent: true,   // 获取对象的数据内容
            showBcs: true,       // 获取对象的BCS编码
        },
    }).then((object) => {
        console.log('Object:', object.data?.bcs);
        const bcsData = object.data?.bcs;
        if (bcsData && typeof bcsData === 'object' && 'bcsBytes' in bcsData) {
            const decodedBcsData = fromBase64(bcsData.bcsBytes);
            console.log('BCS Data:', decodedBcsData);
        }
    }).catch((error) => {
        console.error('Error fetching object:', error);
    });

    return (
        <div>

        </div>
    );
}
