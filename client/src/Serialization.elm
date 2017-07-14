module Serialization
  exposing
    ( BitVector
    , DeserializationPoint
    , ObjectReadSession
    , beginDeserialization
    , bitVectorToDebugString
    , checkNull
    , expectTypeOrNull
    , isDone
    , readBitVector
    , readBoolean
    , readByte
    , readDataDescription
    , readFloat
    , readInt
    , readLong
    , readObject
    , readRawBoolean
    , readRawByte
    , readRawBytes
    , readRawDataDescription
    , readRawFloat
    , readRawInt
    , readRawLong
    , readRawObject
    , readRawShort
    , readShort
    , readString
    , readType
    )

import Array exposing (Array)
import Binary.ArrayBuffer as Buffer
import Bitwise
import Common exposing (intentionalCrash, iterateFoldl, sure)
import List.Extra
import Native.Serialization
import ObjectModelNode exposing (..)
import ValueTree exposing (..)


type alias DeserializationPoint =
  { pos : Int
  , len : Int
  , arr : Buffer.Uint8Array
  , models : List ObjectModelNode
  , valueTrees : List ValueTree
  }


type alias ObjectReadSession =
  { valueTrees : List ( ValueTreeId, Maybe ObjectModelNodeId )
  }


type alias LongContainer =
  ( Int, Int )


type alias BitVector =
  Array Bool


integerSize : number
integerSize =
  32


beginDeserialization : List ObjectModelNode -> List ValueTree -> Buffer.ArrayBuffer -> DeserializationPoint
beginDeserialization objModels valueTrees buf =
  let
    arr =
      Buffer.asUint8Array buf
  in
  { pos = 0, len = Buffer.byteLength buf, arr = arr, models = objModels, valueTrees = valueTrees }


intBitsToFloat : Int -> Float
intBitsToFloat int =
  Native.Serialization.intBitsToFloat int


isDone : DeserializationPoint -> Bool
isDone des =
  des.pos >= des.len


readRawByte : DeserializationPoint -> ( DeserializationPoint, Int )
readRawByte des =
  let
    byte =
      Buffer.getByte des.arr des.pos
  in
  ( { des | pos = des.pos + 1 }, byte )


readByte : DeserializationPoint -> ( DeserializationPoint, Int )
readByte des =
  let
    newDes =
      checkType des TByte
  in
  readRawByte newDes


readRawShort : DeserializationPoint -> ( DeserializationPoint, Int )
readRawShort des =
  let
    byte1 =
      Buffer.getByte des.arr des.pos

    byte2 =
      Buffer.getByte des.arr (des.pos + 1)

    newDes =
      { des | pos = des.pos + 2 }

    val1 =
      Bitwise.shiftLeftBy 8 (Bitwise.and byte1 0xFF)

    val2 =
      Bitwise.and byte2 0xFF

    val =
      Bitwise.or val1 val2
  in
  ( newDes, val )


readShort : DeserializationPoint -> ( DeserializationPoint, Int )
readShort des =
  let
    newDes =
      checkType des TShort
  in
  readRawShort newDes


readRawInt : DeserializationPoint -> ( DeserializationPoint, Int )
readRawInt des =
  let
    byte1 =
      Buffer.getByte des.arr des.pos

    byte2 =
      Buffer.getByte des.arr (des.pos + 1)

    byte3 =
      Buffer.getByte des.arr (des.pos + 2)

    byte4 =
      Buffer.getByte des.arr (des.pos + 3)

    newDes =
      { des | pos = des.pos + 4 }

    val1 =
      Bitwise.shiftLeftBy 24 (Bitwise.and byte1 0xFF)

    val2 =
      Bitwise.shiftLeftBy 16 (Bitwise.and byte2 0xFF)

    val3 =
      Bitwise.shiftLeftBy 8 (Bitwise.and byte3 0xFF)

    val4 =
      Bitwise.and byte4 0xFF

    val =
      Bitwise.or (Bitwise.or (Bitwise.or val1 val2) val3) val4
  in
  ( newDes, val )


readInt : DeserializationPoint -> ( DeserializationPoint, Int )
readInt des =
  let
    newDes =
      checkType des TInt
  in
  readRawInt newDes


readRawLong : DeserializationPoint -> ( DeserializationPoint, LongContainer )
readRawLong des =
  let
    ( des1, int1 ) =
      readRawInt des

    ( des2, int2 ) =
      readRawInt des1
  in
  ( des2, ( int1, int2 ) )


readLong : DeserializationPoint -> ( DeserializationPoint, LongContainer )
readLong des =
  let
    newDes =
      checkType des TLong
  in
  readRawLong newDes


readRawBytes : DeserializationPoint -> Int -> ( DeserializationPoint, Buffer.ArrayBuffer )
readRawBytes des0 len =
  let
    buf =
      Buffer.new len

    arr =
      Buffer.asUint8Array buf

    read des left pos arr =
      if left > 0 then
        let
          ( newDes, byte ) =
            readRawByte des

          newBuf =
            Buffer.setByte arr pos byte
        in
        read newDes (left - 1) (pos + 1) newBuf
      else
        ( des, buf )
  in
  read des0 len 0 arr


readString : DeserializationPoint -> ( DeserializationPoint, Maybe String )
readString des0 =
  let
    ( des1, isNull ) =
      checkNull des0
  in
  if isNull then
    ( des1, Nothing )
  else
    let
      des2 =
        checkType des1 TString

      ( des3, len ) =
        readRawInt des2

      ( des4, strBuf ) =
        readRawBytes des3 len
    in
    ( des4, Just (Buffer.bytesToString strBuf) )


readRawBoolean : DeserializationPoint -> ( DeserializationPoint, Bool )
readRawBoolean des0 =
  let
    ( des1, byte ) =
      readRawByte des0
  in
  ( des1, byte /= 0 )


readBoolean : DeserializationPoint -> ( DeserializationPoint, Bool )
readBoolean des0 =
  let
    des1 =
      checkType des0 TBoolean
  in
  readRawBoolean des1


readRawFloat : DeserializationPoint -> ( DeserializationPoint, Float )
readRawFloat des0 =
  let
    ( des1, int ) =
      readRawInt des0
  in
  ( des1, intBitsToFloat int )


readFloat : DeserializationPoint -> ( DeserializationPoint, Float )
readFloat des0 =
  let
    des1 =
      checkType des0 TFloat
  in
  readRawFloat des1



-- TODO: readDouble??? there is no such type in Elm


readBitVector : DeserializationPoint -> ( DeserializationPoint, Maybe BitVector )
readBitVector des0 =
  let
    ( des1, isNull ) =
      checkNull des0
  in
  if isNull then
    ( des1, Nothing )
  else
    let
      des2 =
        checkType des1 TBitVector

      ( des3, allBitsCount ) =
        readRawShort des2

      arr =
        Array.initialize allBitsCount (always False)

      intsToRead =
        allBitsCount % integerSize

      saveIntToBits : Int -> Array Bool -> Int -> Int -> Array Bool
      saveIntToBits int arr offset bitsCount =
        if bitsCount > 0 then
          let
            bit =
              Bitwise.and int 1

            newArr =
              Array.set offset (bit == 1) arr
          in
          saveIntToBits (Bitwise.shiftRightBy 1 int) newArr (offset + 1) (bitsCount - 1)
        else
          arr

      readBits leftBits des offset out_arr =
        if leftBits > 0 then
          let
            ( newDes, int ) =
              readRawInt des

            out_newArr =
              saveIntToBits int out_arr offset (leftBits % 32)
          in
          readBits (leftBits - integerSize) newDes (offset + integerSize) out_newArr
        else
          ( des, out_arr )

      ( finalDes, finalArr ) =
        readBits intsToRead des3 0 arr
    in
    ( finalDes, Just finalArr )


bitVectorToDebugString : BitVector -> String
bitVectorToDebugString bits =
  Array.foldl
    (\a acc ->
      acc
        ++ toString
            (if a == True then
              1
             else
              0
            )
    )
    ""
    bits


readType : DeserializationPoint -> ( DeserializationPoint, DataType )
readType des0 =
  let
    ( des1, byte ) =
      readRawByte des0
  in
  ( des1, intToType byte )


checkType : DeserializationPoint -> DataType -> DeserializationPoint
checkType des0 expectedType =
  let
    ( des1, aType ) =
      readType des0
  in
  if aType == expectedType then
    des1
  else
    intentionalCrash des0 ("Types are divergent, expected: " ++ toString expectedType ++ ", got: " ++ toString aType)


peekType : DeserializationPoint -> DataType -> Bool
peekType des expectedType =
  typeToInt expectedType == Buffer.getByte des.arr des.pos


expectTypeOrNull : DeserializationPoint -> DataType -> ( DeserializationPoint, Bool )
expectTypeOrNull des expectedType =
  let
    ( newDes, aType ) =
      readType des

    isNull =
      aType == TNull
  in
  if aType == expectedType || isNull then
    ( newDes, not isNull )
  else
    ( des, intentionalCrash False ("Types are divergent, expected: " ++ toString expectedType ++ ", got: " ++ toString aType) )


checkNull : DeserializationPoint -> ( DeserializationPoint, Bool )
checkNull des =
  if peekType des TNull then
    let
      ( newDes, byte ) =
        readRawByte des
    in
    ( newDes, True )
  else
    ( des, False )


readDataDescription : DeserializationPoint -> ( DeserializationPoint, ObjectModelNodeId )
readDataDescription des0 =
  let
    ( des1, aType ) =
      readType des0
  in
  if aType == TDescription then
    readRawDataDescription des1
  else if aType == TDescriptionRef then
    readRawInt des1
  else
    intentionalCrash ( des0, 0 ) ("unexpectedType" ++ toString aType)


readRawDataDescription : DeserializationPoint -> ( DeserializationPoint, ObjectModelNodeId )
readRawDataDescription des0 =
  let
    ( des1, objModelId ) =
      readRawInt des0

    ( des2, name ) =
      readString des1

    ( des3, isTypePrimitive ) =
      readBoolean des2

    ( des4, nodeType ) =
      readType des3

    newObjModel : ObjectModelNode
    newObjModel =
      createModelNode objModelId

    updatedObjModel0 : ObjectModelNode
    updatedObjModel0 =
      { newObjModel
        | name = name
        , isTypePrimitive = isTypePrimitive
        , dataType = nodeType
      }
  in
  if nodeType == TObject then
    let
      ( des5, n ) =
        readRawInt des4

      ( des6, childrenIds ) =
        iterateFoldl
          (\( des, childrenIds ) idx ->
            let
              ( newDes, childObjModelId ) =
                readDataDescription des
            in
            ( newDes, childObjModelId :: childrenIds )
          )
          ( des5, [] )
          0
          (n - 1)

      updatedObjModel1 =
        { updatedObjModel0 | children = Just childrenIds }
    in
    ( { des6 | models = updatedObjModel1 :: des6.models }, objModelId )
  else if nodeType == TArray then
    let
      ( des5, dataSubType ) =
        readType des4

      updatedObjModel1 =
        { updatedObjModel0 | dataSubType = Just dataSubType }
    in
    if isSimpleType dataSubType then
      ( { des5 | models = updatedObjModel1 :: des5.models }, objModelId )
    else if dataSubType == TObject then
      -- nothing special here
      ( { des5 | models = updatedObjModel1 :: des5.models }, objModelId )
    else if dataSubType == TEnum then
      Debug.crash "TODO" ( des5, objModelId )
    else if dataSubType == TArray then
      Debug.crash "TODO" ( des5, objModelId )
    else
      intentionalCrash ( des0, 0 ) ("unsupported array type: " ++ toString dataSubType)
  else if nodeType == TEnum then
    Debug.crash "TODO" ( des4, objModelId )
  else if nodeType == TEnumValue then
    Debug.crash "TODO" ( des4, objModelId )
  else if nodeType == TEnumDescription then
    Debug.crash "TODO" ( des4, objModelId )
  else if isSimpleType nodeType then
    -- nothing special here
    ( { des4 | models = updatedObjModel0 :: des4.models }, objModelId )
  else
    intentionalCrash ( des0, 0 ) ("unsupported type: " ++ toString nodeType)


readObject : DeserializationPoint -> ObjectModelNodeId -> ( DeserializationPoint, ObjectReadSession, Maybe ValueTreeId )
readObject des0 objModelId =
  let
    session : ObjectReadSession
    session =
      { valueTrees = [] }
  in
  readObjectWithSession des0 objModelId session


readObjectWithSession : DeserializationPoint -> ObjectModelNodeId -> ObjectReadSession -> ( DeserializationPoint, ObjectReadSession, Maybe ValueTreeId )
readObjectWithSession des0 objModelId objReadSession =
  let
    des1 =
      checkType des0 TObject
  in
  readRawObject des1 objModelId Nothing objReadSession


readRawObject : DeserializationPoint -> ObjectModelNodeId -> Maybe ValueTreeId -> ObjectReadSession -> ( DeserializationPoint, ObjectReadSession, Maybe ValueTreeId )
readRawObject des0 objModelId maybeParentValueTreeId objReadSession0 =
  let
    ( des1, isNull ) =
      checkNull des0

    objModel =
      getObjectModelById des0.models objModelId
  in
  if isNull then
    ( des1, objReadSession0, Nothing )
  else if objModel.dataType == TObject || objModel.dataType == TUnknown then
    let
      ( des2, dataType ) =
        readType des1

      ( des3, id ) =
        readRawShort des2
    in
    if dataType == TObject then
      let
        n =
          List.length (Maybe.withDefault [] objModel.children)

        tree : ValueTree
        tree =
          createValueTree id maybeParentValueTreeId (Just objModelId)

        objReadSession1 =
          rememberInSession objReadSession0 id (Just objModelId)

        ( des4, objReadSession2, valueTreeIds ) =
          iterateFoldl
            (\( des, session, valueTreeIds ) idx ->
              let
                childObjModelId =
                  List.Extra.getAt idx (sure objModel.children)

                ( des1, session1, valueTreeId ) =
                  readRawObject des (sure childObjModelId) (Just id) session
              in
              ( des1, session1, valueTreeId :: valueTreeIds )
            )
            ( des3, objReadSession1, [] )
            0
            (n - 1)
      in
      -- other valueTrees are saved inside at this point
      ( { des4 | valueTrees = tree :: des4.valueTrees }, objReadSession2, Just id )
    else if dataType == TObjectRef then
      -- TODO
      ( des3, objReadSession0, Just id )
    else if dataType == TArray then
      let
        {- TODO HACK: we should identify every array. A hack copied from original project. -}
        des4 =
          { des3 | pos = des3.pos - 3 }

        ( des5, session, arrayValueId ) =
          readArrayWithSession des4 objReadSession0

        -- TODO assign parent vtree
      in
      ( des5, objReadSession0, Nothing )
    else
      intentionalCrash ( des3, objReadSession0, Nothing ) ("Types are divergent, expected: " ++ toString TObject ++ " or " ++ toString TObjectRef ++ ", got: " ++ toString dataType)
  else if isSimpleType objModel.dataType then
    -- TODO
    ( des1, objReadSession0, Nothing )
  else if objModel.dataType == TEnum then
    -- TODO
    ( des1, objReadSession0, Nothing )
  else if objModel.dataType == TArray then
    -- TODO
    ( des1, objReadSession0, Nothing )
  else
    intentionalCrash ( des1, objReadSession0, Nothing ) ("unsupported type:" ++ (toString objModel.dataType ++ ", subtype: " ++ toString objModel.dataSubType))


beginArray :
  DeserializationPoint
  -> ( DeserializationPoint, Bool, DataType, Int )
beginArray des0 =
  let
    des1 =
      checkType des0 TArray

    ( des2, isPrimitive ) =
      readRawBoolean des1

    ( des3, elementType ) =
      readType des2

    ( des4, size ) =
      readRawInt des3
  in
  ( des1, isPrimitive, elementType, size )


peekArray :
  DeserializationPoint
  -> ( Bool, DataType, Int )
peekArray des =
  let
    ( _, isPrimitive, elementType, size ) =
      beginArray des
  in
  ( isPrimitive, elementType, size )


readArray :
  DeserializationPoint
  -> ( DeserializationPoint, ObjectReadSession, Maybe ValueTreeId )
readArray des0 =
  let
    session : ObjectReadSession
    session =
      { valueTrees = [] }
  in
  readArrayWithSession des0 session


{-| Read array without a known model a priori.
-}
readArrayWithSession :
  DeserializationPoint
  -> ObjectReadSession
  -> ( DeserializationPoint, ObjectReadSession, Maybe ValueTreeId )
readArrayWithSession des0 session =
  let
    ( des1, objModelId ) =
      possiblyReadDescriptions des0 False

    ( des2, isNull ) =
      checkNull des1
  in
  case objModelId of
    Just objModelId ->
      let
        objModel =
          getObjectModelById des2.models objModelId
      in
      if objModel.dataType == TArray then
        -- TODO
        ( des2, session, Nothing )
      else
        -- TODO
        ( des2, session, Nothing )

    Nothing ->
      -- TODO
      ( des0, session, Nothing )


readArrayWithSessionAndModel :
  DeserializationPoint
  -> ObjectReadSession
  -> ObjectModelNodeId
  -> ( DeserializationPoint, ObjectReadSession, Maybe ValueTreeId )
readArrayWithSessionAndModel des0 session0 objModelId =
  let
    ( des1, isNull ) =
      checkNull des0

    objModel =
      getObjectModelById des0.models objModelId
  in
  if isNull then
    ( des1, session0, Nothing )
  else if objModel.isSubTypePrimitive then
    ( des1, session0, Nothing )
  else
    ( des1, session0, Nothing )


possiblyReadDescriptions :
  DeserializationPoint
  -> Bool
  -> ( DeserializationPoint, Maybe ObjectModelNodeId )
possiblyReadDescriptions des0 force =
  let
    ( des1, isOk ) =
      checkIfHasDescription des0 force
  in
  if not isOk then
    ( des1, Nothing )
  else
    let
      ( des2, descrCount ) =
        readRawInt des1
    in
    if descrCount > 0 then
      let
        ( des3, lastModelId ) =
          iterateFoldl
            (\( des, lastModelId ) idx ->
              let
                ( newDes, objModelId ) =
                  readDataDescription des
              in
              ( newDes, Just objModelId )
            )
            ( des2, Nothing )
            0
            (descrCount - 1)
      in
      ( des3, lastModelId )
    else
      let
        des3 =
          checkType des2 TDescriptionRef

        ( des4, objModelId ) =
          readRawInt des3
      in
      ( des4, Just objModelId )


checkIfHasDescription :
  DeserializationPoint
  -> Bool
  -> ( DeserializationPoint, Bool )
checkIfHasDescription des0 force =
  if force then
    let
      des1 =
        checkType des0 TMultipleDescriptions
    in
    ( des1, True )
  else if not <| peekType des0 TMultipleDescriptions then
    ( des0, False )
  else
    ( des0, True )


rememberInSession : ObjectReadSession -> ValueTreeId -> Maybe ObjectModelNodeId -> ObjectReadSession
rememberInSession session id objModelId =
  { session | valueTrees = ( id, objModelId ) :: session.valueTrees }



{-
   # TODO:
    * readObject
    * possiblyReadDescriptions
    * readArray
    * readPrimitive*Array
-}
