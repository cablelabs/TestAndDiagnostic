/*
 * If not stated otherwise in this file or this component's Licenses.txt file the
 * following copyright and licenses apply:
 *
 * Copyright 2015 RDK Management
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
*/

/**********************************************************************
   Copyright [2014] [Cisco Systems, Inc.]
 
   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at
 
       http://www.apache.org/licenses/LICENSE-2.0
 
   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
**********************************************************************/

/**************************************************************************

    module: cosa_diagnostic_apis.c

        For COSA Data Model Library Development

    -------------------------------------------------------------------

    copyright:

        Cisco Systems, Inc.
        All Rights Reserved.

    -------------------------------------------------------------------

    description:

        This file implementes back-end apis for the COSA Data Model Library

        *  CosaDiagCreate
        *  CosaDiagInitialize
        *  CosaDiagRemove
    -------------------------------------------------------------------

    environment:

        platform independent

    -------------------------------------------------------------------

    author:

        COSA XML TOOL CODE GENERATOR 1.0

    -------------------------------------------------------------------

    revision:

        01/11/2011    initial revision.

**************************************************************************/
#include "plugin_main_apis.h"
#include "cosa_diagnostic_apis.h"

/**********************************************************************

    caller:     owner of the object

    prototype:

        ANSC_HANDLE
        CosaDiagCreate
            (
                VOID
            );

    description:

        This function constructs cosa diagnostic object and return handle.

    argument:

    return:     newly created nat object.

**********************************************************************/

ANSC_HANDLE
CosaDiagCreate
    (
        VOID
    )
{
    ANSC_STATUS                     returnStatus = ANSC_STATUS_SUCCESS;
    PCOSA_DATAMODEL_DIAG            pMyObject    = (PCOSA_DATAMODEL_DIAG)NULL;

    /*
     * We create object by first allocating memory for holding the variables and member functions.
     */
    pMyObject = (PCOSA_DATAMODEL_DIAG)AnscAllocateMemory(sizeof(COSA_DATAMODEL_DIAG));

    if ( !pMyObject )
    {
        return  (ANSC_HANDLE)NULL;
    }

    /*
     * Initialize the common variables and functions for a container object.
     */
    pMyObject->Oid               = COSA_DATAMODEL_DIAG_OID;
    pMyObject->Create            = CosaDiagCreate;
    pMyObject->Remove            = CosaDiagRemove;
    pMyObject->Initialize        = CosaDiagInitialize;

    pMyObject->Initialize   ((ANSC_HANDLE)pMyObject);

    return  (ANSC_HANDLE)pMyObject;
}

/**********************************************************************

    caller:     self

    prototype:

        ANSC_STATUS
        CosaDiagInitialize
            (
                ANSC_HANDLE                 hThisObject
            );

    description:

        This function initiate  cosa diagnostic object and return handle.

    argument:   ANSC_HANDLE                 hThisObject
                This handle is actually the pointer of this object
                itself.

    return:     operation status.

**********************************************************************/

ANSC_STATUS
CosaDiagInitialize
    (
        ANSC_HANDLE                 hThisObject
    )
{
    ANSC_STATUS                     returnStatus         = ANSC_STATUS_SUCCESS;
    PCOSA_DATAMODEL_DIAG            pMyObject            = (PCOSA_DATAMODEL_DIAG )hThisObject;
    PDSLH_PING_INFO                 pDiagPingInfo        = (PDSLH_PING_INFO      )NULL;
    PDSLH_TRACEROUTE_INFO           pDiagTracerouteInfo  = (PDSLH_TRACEROUTE_INFO)NULL;
    PDSLH_NSLOOKUP_INFO             pDiagNSLookInfo      = (PDSLH_NSLOOKUP_INFO  )NULL;
    PDSLH_TR143_DOWNLOAD_DIAG_INFO  pDownloadInfo        = (PDSLH_TR143_DOWNLOAD_DIAG_INFO)NULL;
    PDSLH_TR143_UPLOAD_DIAG_INFO    pUploadInfo          = (PDSLH_TR143_UPLOAD_DIAG_INFO)NULL;
    PDSLH_TR143_UDP_ECHO_CONFIG     pUdpEchoInfo         = (PDSLH_TR143_UDP_ECHO_CONFIG)NULL;
    PCOSA_DML_DIAG_ARP_TABLE        pArpTable            = (PCOSA_DML_DIAG_ARP_TABLE)NULL;

    pDiagPingInfo = AnscAllocateMemory(sizeof(DSLH_PING_INFO));

    if ( !pDiagPingInfo )
    {
        return ANSC_STATUS_RESOURCES;
    }
    else
    {
        DslhInitPingInfo(pDiagPingInfo);
        pMyObject->hDiagPingInfo = (ANSC_HANDLE)pDiagPingInfo;
    }

    pDiagTracerouteInfo = AnscAllocateMemory(sizeof(DSLH_TRACEROUTE_INFO));

    if ( !pDiagTracerouteInfo )
    {
        AnscFreeMemory((ANSC_HANDLE)pMyObject->hDiagPingInfo);
        pMyObject->hDiagPingInfo = NULL;
        return ANSC_STATUS_RESOURCES;
    }
    else
    {
        DslhInitTracerouteInfo(pDiagTracerouteInfo);
        pMyObject->hDiagTracerouteInfo = (ANSC_HANDLE)pDiagTracerouteInfo;
    }

    pDiagNSLookInfo = AnscAllocateMemory(sizeof(DSLH_NSLOOKUP_INFO));

    if ( !pDiagNSLookInfo )
    {
        AnscFreeMemory((ANSC_HANDLE)pMyObject->hDiagPingInfo);
        AnscFreeMemory((ANSC_HANDLE)pMyObject->hDiagTracerouteInfo);
        pMyObject->hDiagPingInfo = NULL;
        pMyObject->hDiagTracerouteInfo = NULL;
        return ANSC_STATUS_RESOURCES;
    }
    else
    {
        DslhInitNSLookupInfo(pDiagNSLookInfo);
        pMyObject->hDiagNSLookInfo = (ANSC_HANDLE)pDiagNSLookInfo;
    }

    /* Init Download diagnostics configurations */
    pDownloadInfo = AnscAllocateMemory(sizeof(DSLH_TR143_DOWNLOAD_DIAG_INFO));

    if ( !pDownloadInfo )
    {
        AnscFreeMemory((ANSC_HANDLE)pMyObject->hDiagPingInfo);
        AnscFreeMemory((ANSC_HANDLE)pMyObject->hDiagTracerouteInfo);
        AnscFreeMemory((ANSC_HANDLE)pMyObject->hDiagNSLookInfo);
        pMyObject->hDiagPingInfo = NULL;
        pMyObject->hDiagTracerouteInfo = NULL;
        pMyObject->hDiagNSLookInfo = NULL;
        return ANSC_STATUS_RESOURCES;
    }
    else
    {
        DslhInitDownloadDiagInfo(pDownloadInfo);
        pMyObject->hDiagDownloadInfo = (ANSC_HANDLE)pDownloadInfo;
    }

    /* Init Upload diagnostics configurations */
    pUploadInfo = AnscAllocateMemory(sizeof(DSLH_TR143_UPLOAD_DIAG_INFO));

    if ( !pUploadInfo )
    {
        AnscFreeMemory((ANSC_HANDLE)pMyObject->hDiagPingInfo);
        AnscFreeMemory((ANSC_HANDLE)pMyObject->hDiagTracerouteInfo);
        AnscFreeMemory((ANSC_HANDLE)pMyObject->hDiagNSLookInfo);
        AnscFreeMemory((ANSC_HANDLE)pMyObject->hDiagDownloadInfo);
        pMyObject->hDiagPingInfo = NULL;
        pMyObject->hDiagTracerouteInfo = NULL;
        pMyObject->hDiagNSLookInfo = NULL;
        pMyObject->hDiagDownloadInfo = NULL;
        return ANSC_STATUS_RESOURCES;
    }
    else
    {
        DslhInitUploadDiagInfo(pUploadInfo);
        pMyObject->hDiagUploadInfo = (ANSC_HANDLE)pUploadInfo;
    }

    /* Init UDP ECHO server diagnostics configurations */
    pUdpEchoInfo = AnscAllocateMemory(sizeof(DSLH_TR143_UDP_ECHO_CONFIG));

    if ( !pUdpEchoInfo )
    {
        AnscFreeMemory((ANSC_HANDLE)pMyObject->hDiagPingInfo);
        AnscFreeMemory((ANSC_HANDLE)pMyObject->hDiagTracerouteInfo);
        AnscFreeMemory((ANSC_HANDLE)pMyObject->hDiagNSLookInfo);
        AnscFreeMemory((ANSC_HANDLE)pMyObject->hDiagDownloadInfo);
        AnscFreeMemory((ANSC_HANDLE)pMyObject->hDiagUploadInfo);
        pMyObject->hDiagPingInfo = NULL;
        pMyObject->hDiagTracerouteInfo = NULL;
        pMyObject->hDiagNSLookInfo = NULL;
        pMyObject->hDiagDownloadInfo = NULL;
        pMyObject->hDiagUploadInfo = NULL;
        return ANSC_STATUS_RESOURCES;
    }
    else
    {
        DslhInitUDPEchoConfig(pUdpEchoInfo);
        pMyObject->hDiagUdpechoSrvInfo = (ANSC_HANDLE)pUdpEchoInfo;
    }

    /* initiate ARPTable */
    pMyObject->pArpTable          = NULL;
    pMyObject->ArpEntryCount      = 0;
    pMyObject->PreviousVisitTime  = 0;


    /* Initiation all functions */

    return returnStatus;
}

/**********************************************************************

    caller:     self

    prototype:

        ANSC_STATUS
        CosaDiagRemove
            (
                ANSC_HANDLE                 hThisObject
            );

    description:

        This function initiate  cosa diagnostic object and return handle.

    argument:   ANSC_HANDLE                 hThisObject
                This handle is actually the pointer of this object
                itself.

    return:     operation status.

**********************************************************************/

ANSC_STATUS
CosaDiagRemove
    (
        ANSC_HANDLE                 hThisObject
    )
{
    ANSC_STATUS                     returnStatus = ANSC_STATUS_SUCCESS;
    PCOSA_DATAMODEL_DIAG            pMyObject    = (PCOSA_DATAMODEL_DIAG)hThisObject;

    /* Remove necessary resounce */

    if ( pMyObject->hDiagPingInfo )
    {
        AnscFreeMemory((ANSC_HANDLE)pMyObject->hDiagPingInfo);
    }

    if ( pMyObject->hDiagTracerouteInfo )
    {
        AnscFreeMemory((ANSC_HANDLE)pMyObject->hDiagTracerouteInfo);
    }

    if ( pMyObject->hDiagNSLookInfo )
    {
        AnscFreeMemory((ANSC_HANDLE)pMyObject->hDiagNSLookInfo);
    }

    if ( pMyObject->hDiagDownloadInfo )
    {
        AnscFreeMemory((ANSC_HANDLE)pMyObject->hDiagDownloadInfo);
    }

    if ( pMyObject->hDiagUploadInfo )
    {
        AnscFreeMemory((ANSC_HANDLE)pMyObject->hDiagUploadInfo);
    }

    if ( pMyObject->hDiagUdpechoSrvInfo )
    {
        AnscFreeMemory((ANSC_HANDLE)pMyObject->hDiagUdpechoSrvInfo);
    }

    if ( pMyObject->pArpTable )
    {
        AnscFreeMemory(pMyObject->pArpTable);
    }

    /* Remove self */
    AnscFreeMemory((ANSC_HANDLE)pMyObject);

    return returnStatus;
}


/**********************************************************************

    caller:     COSA Xcalibur dmlib

    prototype:

        ANSC_STATUS
        CosaDmlDiagScheduleDiagnostic
        (
            ULONG                       ulDiagType,
            ANSC_HANDLE                 hDiagInfo
        );

    description:

        This function sets the backend diagnostic parameter
        and schedules a diagnostic process.

    argument:   ULONG                       ulDiagType
                This indicates the diagnostic type.

                ANSC_HANDLE                 hDiagInfo
                This handle is the pointer of diagnostic parameter.

    return:     operation status.

**********************************************************************/
struct AsyncDiagInfo
{
    ULONG        type;
    ANSC_HANDLE  hDiagInfo
};

static void * _AsyncScheduleDiagnostic(ANSC_HANDLE hCtx)
{
    struct AsyncDiagInfo *          pInfo = hCtx;
    
    if (!pInfo)
        return NULL;

    g_pCosaDiagPluginInfo->ScheduleDiagnosticProc
        (
            pInfo->type,
            NULL,
            pInfo->hDiagInfo
        );    

    AnscFreeMemory(pInfo);

    return NULL;
}



ANSC_STATUS
CosaDmlDiagScheduleDiagnostic
    (
        ULONG                       ulDiagType,
        ANSC_HANDLE                 hDiagInfo
    )
{
    ANSC_STATUS                     returnStatus = ANSC_STATUS_FAILURE;
    struct  AsyncDiagInfo  *        pInfo       = NULL;

    /*
    * you can replace this function calling with your
    * own real diagnostic process
    */

    if ( g_pCosaDiagPluginInfo )
    {
        if ( g_pCosaDiagPluginInfo->uLoadStatus != COSA_STATUS_SUCCESS )
        {
            AnscTraceWarning(("COSA Diagnostic library is not ready...\n"));

            return ANSC_STATUS_FAILURE;
        }

        pInfo = AnscAllocateMemory(sizeof(*pInfo));

        if (!pInfo)
            return ANSC_STATUS_FAILURE;

        pInfo->type      = ulDiagType;
        pInfo->hDiagInfo = hDiagInfo;
        
        AnscSpawnTask
            (
                (void *)_AsyncScheduleDiagnostic,
                (ANSC_HANDLE)pInfo,
                "AsyncSheduleDiagnostic"
            );
    }

    return returnStatus;
}

/**********************************************************************

    caller:     COSA Xcalibur dmlib

    prototype:

        ANSC_STATUS
        CosaDmlDiagCancelDiagnostic
        (
            ULONG                       ulDiagType
        );

    description:

        This function stops backend diagnostic process.

    argument:   ULONG                       ulDiagType
                This indicates the diagnostic type.

    return:     operation status.

**********************************************************************/

ANSC_STATUS
CosaDmlDiagCancelDiagnostic
    (
        ULONG                       ulDiagType
    )
{
    ANSC_STATUS                     returnStatus = ANSC_STATUS_FAILURE;

    /*
    * you can replace this function calling with your
    * own real diagnostic process
    */

    if ( g_pCosaDiagPluginInfo )
    {
        if ( g_pCosaDiagPluginInfo->uLoadStatus != COSA_STATUS_SUCCESS )
        {
            AnscTraceWarning(("COSA Diagnostic library is not ready...\n"));

            return returnStatus;
        }

        returnStatus = g_pCosaDiagPluginInfo->CancelDiagnosticProc(ulDiagType, NULL);
    }

    return returnStatus;
}

/**********************************************************************

    caller:     COSA Xcalibur dmlib

    prototype:

        ANSC_HANDLE
        CosaDmlDiagGetResults
        (
            ULONG                       ulDiagType
        )

    description:

        This function gets the diagnostic result from backend.

    argument:   ULONG                       ulDiagType
                This indicates the diagnostic type.

    return:     Handle of diagnostic result.

**********************************************************************/

ANSC_HANDLE
CosaDmlDiagGetResults
    (
        ULONG                       ulDiagType
    )
{
    ANSC_HANDLE                     hDiagInfo = NULL;

    if ( g_pCosaDiagPluginInfo )
    {
        if ( g_pCosaDiagPluginInfo->uLoadStatus != COSA_STATUS_SUCCESS )
        {
            AnscTraceWarning(("COSA Diagnostic library is not ready...\n"));

            return NULL;
        }

        hDiagInfo = g_pCosaDiagPluginInfo->GetResultsProc(ulDiagType, NULL);
    }

    return hDiagInfo;
}


/**********************************************************************

    caller:     COSA Xcalibur dmlib

    prototype:

        ANSC_HANDLE
        CosaDmlDiagSetState
        (
            ULONG                       ulDiagState
        )

    description:

        This function gets the diagnostic result from backend.

    argument:   ULONG                       ulDiagType
                This indicates the diagnostic type.

    return:     Handle of diagnostic result.

**********************************************************************/

ANSC_STATUS
CosaDmlDiagSetState
    (
        ULONG                       ulDiagType,
        ULONG                       ulDiagState
    )
{
    ANSC_STATUS                     returnStatus = ANSC_STATUS_FAILURE;

    if ( g_pCosaDiagPluginInfo )
    {
        
        returnStatus = g_pCosaDiagPluginInfo->SetDiagStateProc(ulDiagType, NULL, ulDiagState);
    }

    return returnStatus;
}


/**********************************************************************

    caller:     COSA Xcalibur dmlib

    prototype:

        ANSC_HANDLE
        CosaDmlDiagGetConfigs
        (
            ULONG                       ulDiagType
        )

    description:

        This function gets the diagnostic configurations from backend.

    argument:   ULONG                       ulDiagType
                This indicates the diagnostic type.

    return:     Handle of diagnostic configurations.

**********************************************************************/

ANSC_HANDLE
CosaDmlDiagGetConfigs
    (
        ULONG                       ulDiagType
    )
{
    ANSC_HANDLE                     hDiagInfo = NULL;

    if ( g_pCosaDiagPluginInfo )
    {
        if ( g_pCosaDiagPluginInfo->uLoadStatus != COSA_STATUS_SUCCESS )
        {
            AnscTraceWarning(("COSA Diagnostic library is not ready...\n"));

            return NULL;
        }

        hDiagInfo = g_pCosaDiagPluginInfo->GetConfigsProc(ulDiagType, NULL);
    }

    return hDiagInfo;
}

PCOSA_DML_DIAG_ARP_TABLE
CosaDmlDiagGetARPTable

    (
        ANSC_HANDLE                 hContext,
        PULONG                      pulCount
    )
{
	//return CosaDmlDiagGetARPTablePriv(hContext, pulCount); //LNT_EMU
}
