"""ZHA quirk for the HV-MRF-01 blinds controller."""

import zigpy.types as t
from zigpy.profiles import zha
from zigpy.zcl.foundation import (
    BaseAttributeDefs,
    BaseCommandDefs,
    ZCLAttributeDef,
    ZCLCommandDef,
)

from zhaquirks.clusters import CustomCluster
from zhaquirks.const import (
    DEVICE_TYPE,
    ENDPOINTS,
    INPUT_CLUSTERS,
    MODELS_INFO,
    OUTPUT_CLUSTERS,
    PROFILE_ID,
)
from zhaquirks.legacy import CustomDevice


MANUFACTURER = "Evan Purkhiser"
MODEL_NAME = "HV-MRF-01"
MANUFACTURER_CODE = 0x131B


class HVMRF01ManufacturerCluster(CustomCluster):
    """Manufacturer-specific config cluster for the HV-MRF-01."""

    cluster_id = 0xFC00
    name = "HV-MRF-01 Config"
    ep_attribute = "hvmrf01_config"

    class AttributeDefs(BaseAttributeDefs):
        """Server attribute definitions."""

        cover_speed = ZCLAttributeDef(
            id=0x0000,
            type=t.uint16_t,
            is_manufacturer_specific=True,
            manufacturer_code=MANUFACTURER_CODE,
        )
        soft_stop_mm = ZCLAttributeDef(
            id=0x0001,
            type=t.uint16_t,
            is_manufacturer_specific=True,
            manufacturer_code=MANUFACTURER_CODE,
        )
        hard_stop_mm = ZCLAttributeDef(
            id=0x0002,
            type=t.uint16_t,
            is_manufacturer_specific=True,
            manufacturer_code=MANUFACTURER_CODE,
        )

    class ServerCommandDefs(BaseCommandDefs):
        """Server command definitions."""

        reboot_debug = ZCLCommandDef(
            id=0x00,
            schema={},
            is_manufacturer_specific=True,
            manufacturer_code=MANUFACTURER_CODE,
        )
        calibrate = ZCLCommandDef(
            id=0x01,
            schema={},
            is_manufacturer_specific=True,
            manufacturer_code=MANUFACTURER_CODE,
        )


class HVMRF01(CustomDevice):
    """HV-MRF-01 blinds controller."""

    signature = {
        MODELS_INFO: [(MANUFACTURER, MODEL_NAME)],
        ENDPOINTS: {
            10: {
                PROFILE_ID: zha.PROFILE_ID,
                DEVICE_TYPE: 0x0202,
                INPUT_CLUSTERS: [0x0000, 0x0003, 0x0004, 0x0005, 0x0102, 0xFC00],
                OUTPUT_CLUSTERS: [],
            },
            242: {
                PROFILE_ID: 0xA1E0,
                DEVICE_TYPE: 0x0060,
                INPUT_CLUSTERS: [],
                OUTPUT_CLUSTERS: [0x0021],
            },
        },
    }

    replacement = {
        ENDPOINTS: {
            10: {
                PROFILE_ID: zha.PROFILE_ID,
                DEVICE_TYPE: 0x0202,
                INPUT_CLUSTERS: [
                    0x0000,
                    0x0003,
                    0x0004,
                    0x0005,
                    0x0102,
                    HVMRF01ManufacturerCluster,
                ],
                OUTPUT_CLUSTERS: [],
            },
            242: {
                PROFILE_ID: 0xA1E0,
                DEVICE_TYPE: 0x0060,
                INPUT_CLUSTERS: [],
                OUTPUT_CLUSTERS: [0x0021],
            },
        },
    }
