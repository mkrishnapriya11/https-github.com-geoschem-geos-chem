!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !MODULE: diag_pl_mod
!
! !DESCRIPTION: Module DIAG\_PL\_MOD contains variables and routines which are 
!  used to compute the production and loss of chemical families in the
!  "full chemistry" (NOx-Ox-Hydrocarbon-aerosol) mechanism.
!\\
!\\
! !INTERFACE:
!
      MODULE DIAG_PL_MOD
!
! !USES:
!
      IMPLICIT NONE
      PRIVATE
!
! !PUBLIC DATA MEMBERS:
!
      ! Scalars
      LOGICAL, PUBLIC              :: DO_SAVE_PL
      INTEGER, PUBLIC              :: TAGO3_PL_YEAR

      ! Arrays
      REAL*4,  PUBLIC, ALLOCATABLE :: AD65  (:,:,:,:)
      REAL*8,  PUBLIC, ALLOCATABLE :: FAM_PL(:,:,:,:)
!
! !PUBLIC MEMBER FUNCTIONS:
!
      PUBLIC  :: DO_DIAG_PL
      PUBLIC  :: CLEANUP_DIAG_PL
      PUBLIC  :: GET_FAM_MWT
      PUBLIC  :: GET_FAM_NAME
      PUBLIC  :: GET_NFAM
      PUBLIC  :: INIT_DIAG_PL
      PUBLIC  :: SETJFAM
      PUBLIC  :: SETPL
!
! !PRIVATE MEMBER FUNCTIONS:
!
      PRIVATE :: DIAG20
      PRIVATE :: ITS_TIME_FOR_WRITE20
      PRIVATE :: WRITE20
!
! !REVISION HISTORY:
!  20 Jul 2004 - R. Yantosca - Initial version
!  (1 ) Add TAUe as a module variable.  Bug fixes: Make sure WRITE20 uses the 
!        global FILENAME, and also write to disk on the last timestep before
!        the end of the simulation. (bmy, 11/15/04)
!  (2 ) Added routine ITS_TIME_FOR_WRITE20 (bmy, 3/3/05)
!  (3 ) Added functions GET_NFAM, GET_FAM_MWT, GET_FAM_NAME (bmy, 5/2/05)
!  (4 ) Now make sure all USE statements are USE, ONLY (bmy, 10/3/05)
!  (5 ) Now references XNUMOL from "tracer_mod.f" (bmy, 10/25/05)
!  (6 ) Bug fix in DIAG20 (phs, 1/22/07)
!  (7 ) Now use LD65 as the vertical dimension instead of LLTROP or LLTROP_FIX
!        in DO_DIAG_PL, DIAG20, and WRITE20 (phs, bmy, 12/4/07)
!  (8 ) Now make COUNT a 3-D array (phs, 11/18/08)
!  (9 ) Minor fix in DIAG20 (dbj, bmy, 10/26/09)
!  16 Sep 2010 - R. Yantosca - Added ProTeX headers
!EOP
!------------------------------------------------------------------------------
!BOC
!
! !PRIVATE TYPES:
!
      ! Scalars
      LOGICAL                        :: DO_SAVE_O3
      INTEGER                        :: NFAM
      INTEGER                        :: YYYYMMDD
      REAL*8                         :: TAUb, TAUe, TAU0, TAU1
      CHARACTER(LEN=255)             :: FILENAME

      ! Arrays
      INTEGER,           ALLOCATABLE :: FAM_NMEM(:), COUNT(:,:,:)
      REAL*8,            ALLOCATABLE :: FAM_COEF(:,:)
      REAL*8,            ALLOCATABLE :: PL24H(:,:,:,:)
      CHARACTER(LEN=14), ALLOCATABLE :: FAM_NAME(:)
      CHARACTER(LEN=14), ALLOCATABLE :: FAM_TYPE(:)
      CHARACTER(LEN=14), ALLOCATABLE :: FAM_MEMB(:,:)

      CONTAINS
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: setjfam
!
! !DESCRIPTION: Subroutine SETJFAM stores info into SMVGEAR arrays for the 
!  ND65 prod/loss diagnostic. 
!\\
!\\
! !INTERFACE:
!
      SUBROUTINE SETJFAM( NACTIVE, NINAC )
!
! !USES:
!
#     include "CMN_SIZE"     ! Size parameters
#     include "comode.h"     ! SMVGEAR II arrays

!
! !INPUT/OUTPUT PARAMETERS: 
! 
      INTEGER, INTENT(INOUT) :: NACTIVE   ! # of active chemical species
      INTEGER, INTENT(INOUT) :: NINAC     ! # of inactive chemical species
!
! !REMARKS:
!  At present, the ND65 diagnostic works only with SMVGEAR and not with
!  KPP.  KPP is generated automatically and lacks the code to keep track of
!  the production/loss of chemical families. (bmy, 9/16/10)
! 
! !REVISION HISTORY:
!  01 Feb 1999- L. Mickley, I. Bey, R. Yantosca - Initial version
!  (1 ) Replace NAMESPEC with NAMEGAS for SMVGEAR II.  Added comment header
!        and updated comments.  Now references IU_FILE and IOERROR from
!        F90 module "file_mod.f".  Now trap I/O errors using routine IOERROR.
!        Make DEFMR a parameter for safety's sake.   Need to increment NACTIVE
!        for SMVGEAR II or else the last species will be overwritten w/ the 
!        first ND65 family.  Set NCS = NCSURBAN, since we have defined our 
!        GEOS-CHEM mechanism in the urban slot of SMVGEAR II.(bmy, 4/21/03)
!  (2 ) Bundled into "diag65_mod.f" (bmy, 7/20/04)
!  15 Sep 2010 - R. Yantosca - Added ProTeX headers 
!EOP
!------------------------------------------------------------------------------
!BOC
!
! !LOCAL VARIABLES:
!
      INTEGER :: F, J, JGAS0, JGAS

      !=================================================================
      ! SETJFAM begins here!
      !=================================================================

      ! Need increment NACTIVE for SMVGEAR II or else the last species
      ! will be overwritten w/ the first ND65 family (bmy, 4/18/03)
      NACTIVE = NACTIVE + 1
      JGAS0   = NACTIVE 

      ! Set NCS = NCSURBAN, since we have defined our GEOS-CHEM 
      ! mechanism in the urban slot of SMVGEAR II. (bmy, 4/21/03)
      NCS     = NCSURBAN

      !=================================================================
      ! Read in family names for prod and loss. Assume these
      ! families are active.  Assume initial mixing ratio = 0d0.
      ! Note that when setjfam is called, nactive = active species +1.
      !=================================================================

      ! Loop over families
      DO F = 1, NFAM

         ! Update variables
         JGAS              = NACTIVE
         NTSPEC(NCS)       = NACTIVE + IGAS - NINAC
         NAMEGAS(JGAS)     = FAM_NAME(F)
         QBKCHEM(JGAS,NCS) = 0d0 
         NACTIVE           = NACTIVE + 1

      ENDDO

      !=================================================================
      ! Write out family names to "smv2.log" file
      !=================================================================
      WRITE( IO93, '(/,a)'      ) REPEAT( '=', 79 )
      WRITE( IO93, '(a)'        ) 'Families for prod or loss output:'
      WRITE( IO93, '(a,/)'      ) REPEAT( '=', 79 )
      WRITE( IO93, '(10(a7,1x))' ) ( TRIM( NAMEGAS(J) ), J=JGAS0,JGAS )

      END SUBROUTINE SETJFAM
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: setpl
!
! !DESCRIPTION: Subroutine SETPL flags the reactions and species which 
!  contribute to production or loss for a given ND65 prodloss diagnostic 
!  family.  
!\\
!\\
! !INTERFACE:
!
      SUBROUTINE SETPL
!
! !USES:
!
      USE ERROR_MOD, ONLY : ERROR_STOP, GEOS_CHEM_STOP
      USE ERROR_MOD,   ONLY : DEBUG_MSG
      USE LOGICAL_MOD, ONLY : LPRT

#     include "CMN_SIZE"
#     include "comode.h"
! 
! !REMARKS:
!  At present, the ND65 diagnostic works only with SMVGEAR and not with
!  KPP.  KPP is generated automatically and lacks the code to keep track of
!  the production/loss of chemical families. (bmy, 9/16/10)
!
! !REVISION HISTORY:
!  01 Feb 1999- L. Mickley, I. Bey, R. Yantosca - Initial version
!  (1 ) Now references "file_mod.f" and "error_mod.f".  Also now use IOERROR 
!        to trap I/O errors, and ERROR_STOP to stop the run and deallocate
!        all module arrays.  NAMESPEC is now NAMEGAS for SMVGEAR II. Now 
!        uses F90 declaration syntax.  Set NCS = NCSURBAN for now, since we 
!        have defined our GEOS-CHEM mechanism in the urban slot of SMVGEAR II
!        Updated comments.  (bmy, 5/1/03)
!  15 Sep 2010 - R. Yantosca - Added ProTeX headers 
!EOP
!------------------------------------------------------------------------------
!BOC
!
! !LOCAL VARIABLES:
!
      INTEGER          :: F, ICOUNT, I, J, INDEX, IOS
      INTEGER          :: K, M, N, NK, NREAC, NPROD, NPOS
      INTEGER          :: IREAC1, IREAC2, IREAC3
      INTEGER          :: IPROD1, IPROD2, IPROD3
      INTEGER          :: NFAMMEM(MAXFAM)
      INTEGER          :: IFAMMEM(MAXMEM,MAXFAM)
      INTEGER          :: ITEMPREAC(NMRPROD) 
      INTEGER          :: NNPL(MAXFAM)
      INTEGER          :: NKPL(MAXPL,MAXFAM)
      INTEGER          :: IPLREAC(NMRPROD,MAXPL,MAXFAM)
      REAL*8           :: PL
      REAL*8           :: COEFMEM(MAXMEM,MAXFAM)
      REAL*8           :: COEFPL(MAXPL,MAXFAM)
      CHARACTER(LEN=5) :: EXTRACHAR

      !=================================================================
      ! SETPL begins here!
      !=================================================================

      ! Set NCS = NCSURBAN for now, since we have defined our GEOS-CHEM
      ! mechanism in the urban slot of SMVGEAR II. (bmy, 4/21/03)
      NCS = NCSURBAN
      
      ! Initialize
      ICOUNT = 0

      !=================================================================
      ! Process family information
      !=================================================================

      ! Set NFAMILIES in "comode.h"
      NFAMILIES = NFAM
      
      ! Loop over families
      DO F = 1, NFAM

         !----------------
         ! Error checks
         !----------------

         ! # of families
         IF ( F > MAXFAM ) THEN
            CALL ERROR_STOP( 'Too many ND65 families!', 'setpl.f' )
         ENDIF

         ! # of members
         IF ( FAM_NMEM(F) > MAXMEM ) THEN
            CALL ERROR_STOP( 'Too many family members!', 'setpl.f' )
         ENDIF 

         !-----------------
         ! Family name
         !-----------------
         DO J = 1, NSPEC(NCS)
            IF ( NAMEGAS(J) == FAM_NAME(F) ) IFAM(F) = J
         ENDDO

         !-----------------
         ! Family type
         !-----------------
         PORL(F) = FAM_TYPE(F)

         ! Convert PORL to lower case if necessary
         IF ( PORL(F) == 'PROD' ) PORL(F) = 'prod'
         IF ( PORL(F) == 'LOSS' ) PORL(F) = 'loss'

         ! Write to "smv2.log"
         WRITE( IO93, 104 ) F, FAM_NAME(F), PORL(F), FAM_NMEM(F) 
 104     FORMAT(/, 'Family ', i2, ' is ' ,a5, ' ', a4,
     &             ' with ',  i2, ' members' )

         WRITE( IO93, 105 ) 
 105     FORMAT( 'ind', 2x, 'species', 1x, 'jnum', 2x, 'coef' )

         !------------------
         ! Family members
         !------------------
         DO M = 1, FAM_NMEM(F) 
            
            ! Coefficient of each member
            COEFMEM(M,F) = FAM_COEF(M,F)

            ! Store each family member in IFAMMEM
            DO J = 1, NSPEC(NCS)
               IF ( NAMEGAS(J) == FAM_MEMB(M,F) ) IFAMMEM(M,F) = J
            ENDDO

            ! Write to "smv2.log"
            WRITE( IO93, '(i2,3x,a5,2x,i3,2x,f5.1 )') 
     &           F, FAM_MEMB(M,F), IFAMMEM(M,F), COEFMEM(M,F)
         ENDDO
      ENDDO

      !=================================================================
      ! Now determine which reactions are sources or sinks of the
      ! specified families. Amend the IRM array accordingly.
      !=================================================================
      DO N = 1, NFAMILIES
         NNPL(N) = 0
      ENDDO

      ! Loop over all rxns (NTRATES = # of kinetic + photo rxns)
      DO NK = 1, NTRATES(NCS)

         ! If this rxn hasn't been turned off...
         IF ( LSKIP(NK,NCS) == 0 ) THEN

            ! Index of first reactant
            IREAC1 = IRM(1,NK,NCS)

            ! Index of first product
            IPROD1 = IRM(NPRODLO,NK,NCS)

            ! Skip emission rxns
            IF ( NAMEGAS(IREAC1) == 'EMISSION' ) GOTO 150  

            ! Skip drydep rxns
            DO N = 1, NDRYDEP(NCS)
               IF ( NK ==  NKDRY(N,NCS) ) GOTO 150
            ENDDO

            !===========================================================
            ! For this rxn, loop over all prod/loss diagnostic families
            !===========================================================
            DO N = 1, NFAMILIES

               ! Initialize for each family
               PL        = 0
               NPROD     = 0
               ICOUNT    = 0
               ITEMPREAC = 0

               !========================================================
               ! For each rxn, loop over reactants and products
               ! and compute how many moles are gained and lost 
               !========================================================
               DO I = 1, NPRODHI

                  ! Increment product count (1st 4 slots are reactants)
                  IF ( I > 4 ) ICOUNT = ICOUNT + 1

                  ! Skip blank entries
                  IF ( IRM(I,NK,NCS) /= 0 ) THEN

                     ! Store reactant index for later use
                     ITEMPREAC(I) = IRM(I,NK,NCS)

                     ! Ensure NPROD skips over the reactant slots of IRM
                     IF ( I     > 4      ) NPROD = NPROD + 1
                     IF ( NPROD < ICOUNT ) NPROD = ICOUNT

                     ! Loop over all family members
                     DO J = 1, FAM_NMEM(N)

                        ! Test for product or reactant
                        IF ( IRM(I,NK,NCS) == IFAMMEM(J,N) ) THEN

                           !============================================
                           ! PRODUCT: The # of moles that prodloss 
                           ! family N gains is the # of moles that 
                           ! species M contributes to family N (i.e. 
                           ! COEFMEM(J,N) ) times the # of moles of 
                           ! species M gained in the reaction (i.e. 
                           ! FKOEF(I,NK,NCS) ).
                           !============================================
                           IF ( I >= NPRODLO ) THEN
                              PL = PL + COEFMEM(J,N) * FKOEF(I,NK,NCS)
                           ENDIF

                           !============================================
                           ! REACTANT: The # of moles that prodloss 
                           ! family N loses is the # of moles that 
                           ! species M contributes to family N (i.e. 
                           ! COEFMEM(J,N) ).  Here FKOEF is almost 
                           ! always 1 for reactants.
                           !============================================
                           IF ( I < NPRODLO ) THEN 
                              PL = PL - COEFMEM(J,N)
                           ENDIF
                        ENDIF   
                     ENDDO      
                  ENDIF         
               ENDDO

               !========================================================
               ! If there is a production or loss for prodloss family 
               ! N, then update IRM and the other arrays
               !========================================================
               IF ( ( PL > 0 .AND. PORL(N) == 'prod' )  .OR.
     &              ( PL < 0 .AND. PORL(N) == 'loss' ) ) THEN

                  ! # of prod or loss rxns for family N
                  NNPL(N)            = NNPL(N) + 1

                  ! Error check
                  IF ( NNPL(N) .GT. MAXPL ) THEN
                     CALL ERROR_STOP( 'Number of rxns exceeds MAXPL!', 
     &                                'setpl.f' )
                  ENDIF   

                  ! Index of IRM for one beyond the next product
                  NPOS               = NPRODLO + NPROD 

                  ! Store # of each rxn in NKPL for output below
                  NKPL(NNPL(N),N)    = NK

                  ! Store P/L coeff for each rxn in COEFPL for output below
                  COEFPL(NNPL(N),N)  = PL

                  ! Store the family name as the "last" product of the
                  ! of the rxn -- in the (NPRODLO+NPROD)th slot of IRM
                  IRM(NPOS,NK,NCS)   = IFAM(N)

                  ! Also store the total prod/loss of family N 
                  ! in the (NPRODLO+NPROD)th of the FKOEF array
                  FKOEF(NPOS,NK,NCS) = ABS( PL )

                  ! Loop over all reactants and products
                  DO I = 1, NMRPROD

                     ! Zero any negative reactant/product indices
                     IF ( ITEMPREAC(I) < 0 ) ITEMPREAC(I) = 0

                     ! 3-body rxn???
                     IF ( ITEMPREAC(3) > 0 ) THEN
                        WRITE( 6, 1190 ) NK
 1190                   FORMAT( 'SETPL: Problem with rxn # ',i4 )
                        CALL GEOS_CHEM_STOP
                     ENDIF

                     ! Save reactants and products for this
                     ! reaction in IPLREAC for output below
                     IPLREAC(I,NNPL(N),N) = ITEMPREAC(I)
                  ENDDO
               ENDIF    
            ENDDO
         ENDIF

         !-------------------------------
         ! Skip emission & drydep rxns 
         !-------------------------------
 150     CONTINUE 
      ENDDO

      !=================================================================
      ! Write out prod or loss reactions to "smv2.log"
      !=================================================================
      WRITE( IO93, '(/,a)' ) REPEAT( '=', 79 )
      WRITE( IO93, '(a)'   ) 'Here are the prod and loss reactions'
      WRITE( IO93, '(a)'   ) REPEAT( '=', 79 )

      ! Loop over P/L diagnostic families
      DO N = 1, NFAMILIES

         ! Write family header
         WRITE( IO93, 587 ) NAMEGAS(IFAM(N)), PORL(N), NNPL(N)
 587     FORMAT( /, 'Family ',a5,' ',a4,' -- no of rxns is  ',i3, 5x,
     &           'coefficient')

         ! Loop over prod/loss reactions
         DO I = 1, NNPL(N)

            ! Rxn number
            NK        = NKPL(I,N)

            ! Reactant indices
            IREAC1    = IPLREAC(1,I,N)
            IREAC2    = IPLREAC(2,I,N)

            ! Product indices
            IPROD1    = IPLREAC( NPRODLO,   I,N)
            IPROD2    = IPLREAC((NPRODLO+1),I,N)
            IPROD3    = IPLREAC((NPRODLO+2),I,N)

            ! Character to denote 3 or more products
            EXTRACHAR = '     '
            IF ( IPROD3 .GT. 0 ) EXTRACHAR = '+ ...'

            ! Test for kinetic or photo rxns
            IF ( NK .LE. NRATES(NCS) ) THEN

               !----------------------
               ! Write kinetic rxns
               !----------------------
               WRITE(IO93,588) I, NK, NAMEGAS(IREAC1),
     &              NAMEGAS(IREAC2),  NAMEGAS(IPROD1),
     &              NAMEGAS(IPROD2),  EXTRACHAR, COEFPL(I,N)

 588           FORMAT(I3,1X,I3,1X,A5,' + ',A5,' = ',A5,' + ',A5,
     &                A5,1X,ES13.6)

            ELSE

               !----------------------
               ! Write photo rxns
               !----------------------
               WRITE(IO93,589) I, NK, NAMEGAS(IREAC1),
     &              NAMEGAS(IPROD1),  NAMEGAS(IPROD2), 
     &              EXTRACHAR,        COEFPL(I,N)

 589           FORMAT(I3,1X,I3,1X,A5,' +  hv   = ',A5,' + ',A5,
     &                A5,1X,1P1E13.6)

            ENDIF        
            
           !### Debug (FP 6/2009)
      IF ( LPRT ) THEN
         CALL DEBUG_MSG( '### SETPL' )
            WRITE(6,*) NAMEGAS(IFAM(N))
            WRITE( 6, '(i4,1x,16(a,'':'')))' ) 
     &           NK, ( TRIM(NAMEGAS(IRM(J,NK,NCS))), J=1,NREAD )
            WRITE( 6, '(i4,1x,4f4.1,''/'',12f4.1)' ) 
     &           NK, ( FKOEF(J,NK,NCS), J=1,NREAD )
      ENDIF

         ENDDO             
      ENDDO

      END SUBROUTINE SETPL
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: do_diag_pl 
!
! !DESCRIPTION: Subroutine DO\_DIAG\_PL saves info on production and loss of 
!  families into the FAM_PL diagnostic array.
!\\
!\\
! !INTERFACE:
!
      SUBROUTINE DO_DIAG_PL 
!
! !USES:
!
      USE COMODE_MOD, ONLY : CSPEC, JLOP

#     include "CMN_SIZE"  ! Size parameters
#     include "CMN_DIAG"  ! LD65
#     include "comode.h"  ! SMVGEAR II arrays
! 
! !REVISION HISTORY:
!  16 Mar 2000 - I. Bey      - Initial version
!  (1 ) Now bundled into "prod_loss_diag_mod.f" (bmy, 7/20/04)
!  (2 ) Now only loop up thru LD65 levels (bmy, 12/4/07)
!  (3 ) Set FAM_PL to zero in the stratosphere (phs, 11/17/08)
!  15 Sep 2010 - R. Yantosca - Added ProTeX headers 
!EOP
!------------------------------------------------------------------------------
!BOC
!
! !LOCAL VARIABLES:
!
      INTEGER :: I, J, L, JLOOP, N

      !=================================================================
      ! DO_DIAG_PL begins here!
      !
      ! If ND65 is turned on, then archive P-L for specified families 
      ! and store in the AD65 array.  
      !
      ! Make sure that memory has already been allocated to arrays
      ! FAMPL, JLOP, and CSPEC.
      !=================================================================

      ! If we are not saving 
      IF ( .not. DO_SAVE_PL ) RETURN

!$OMP PARALLEL DO
!$OMP+DEFAULT( SHARED )
!$OMP+PRIVATE( I, J, L, N, JLOOP )
!$OMP+SCHEDULE( DYNAMIC ) 
      DO N = 1, NFAMILIES
      DO L = 1, LD65
      DO J = 1, NLAT
      DO I = 1, NLONG
         
         ! JLOOP is the 1-D grid box index for SMVGEAR arrays
         JLOOP = JLOP(I,J,L)

         ! If this is a valid grid box
         IF ( JLOOP > 0 ) THEN

            ! Copy the concentration for the "fake" prodloss family
            ! (which have been appended to the SMVGEAR species list)
            ! to the FAM_PL diagnostic array.  Units are [molec/cm3/s].
            FAM_PL(I,J,L,N)      = CSPEC(JLOOP,IFAM(N)) / CHEMINTV

            ! Zero each "fake" ND65 prod/loss family for next iteration
            CSPEC(JLOOP,IFAM(N)) = 0.0d0

            ! Also save into the AD65 diagnostic array
            AD65(I,J,L,N)        = AD65(I,J,L,N) + FAM_PL(I,J,L,N)
         
         ELSE
            
            ! avoid surprises in DIAG20, which uses all FAM_PL boxes
            FAM_PL(I,J,L,N)      = 0.0d0

         ENDIF

      ENDDO
      ENDDO
      ENDDO
      ENDDO
!$OMP END PARALLEL DO

      !=================================================================
      ! Also call DIAG20, which will save out the P(Ox) and L(Ox)
      ! from the fullchem simulation for a future tagged Ox run
      !=================================================================

      IF ( DO_SAVE_O3 ) CALL DIAG20

      END SUBROUTINE DO_DIAG_PL
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: diag20
!
! !DESCRIPTION: Subroutine DIAG20 computes production and loss rates of O3, 
!  and then calls subroutine WRITE20 to save the these rates to disk.  By 
!  saving the production and loss rates from a full-chemistry run,
!  a user can use these archived rates to perform a quick O3 chemistry
!  run at a later time.
!\\
!\\
! !INTERFACE:
!
      SUBROUTINE DIAG20
!
! !USES:
!
      USE COMODE_MOD,    ONLY : JLOP
      USE DIRECTORY_MOD, ONLY : O3PL_DIR
      USE ERROR_MOD,     ONLY : ERROR_STOP
      USE TIME_MOD,      ONLY : EXPAND_DATE,   GET_NYMD
      USE TIME_MOD,      ONLY : GET_TAU,       GET_TAUb 
      USE TIME_MOD,      ONLY : ITS_A_NEW_DAY, TIMESTAMP_STRING
      USE TRACER_MOD,    ONLY : STT,           XNUMOL
      USE TRACERID_MOD,  ONLY : IDTOX

#     include "CMN_SIZE"      ! Size parameters
#     include "CMN_DIAG"      ! LD65
! 
! !REMARKS:
!  DIAG20 assumes that ND65 (P-L diagnostics) have been turned on.
!
! !REVISION HISTORY:
!  09 Jun 1999 - I. Bey      - Initial version
!  (1 ) Now bundled into "diag20_mod.f" (bmy, 7/20/04)
!  (2 ) Now also write to disk when it is the last timestep before the end of 
!        the run.  Now references GET_TAUE from "time_mod.f". (bmy, 11/15/04)
!  (3 ) Now call function ITS_TIME_FOR_WRITE20 to determine if the next
!        chemistry timestep is the start of a new day.  Remove reference
!        to GET_TAUe and GET_TS_CHEM.  Now archive P(Ox) and L(Ox) first
!        and then test if we have to save the file to disk. (bmy, 3/3/05)
!  (4 ) Now references XNUMOL from "tracer_mod.f" (bmy, 10/25/05)
!  (5 ) Now use LLTROP_FIX instead of LLTROP (phs, 1/22/07)
!  (6 ) Now use LD65 instead of LLTROP_FIX (phs, bmy, 12/4/07)
!  (7 ) Now take care of boxes that switch b/w stratospheric and tropospheric
!        regimes (phs, 11/17/08)
!  (8 ) Bug fix: Now just zero arrays w/o loop indices (dbj, bmy, 10/26/09)
!  15 Sep 2010 - R. Yantosca - Added ProTeX headers 
!EOP
!------------------------------------------------------------------------------
!BOC
!
! !LOCAL VARIABLES:
!
      LOGICAL, SAVE     :: FIRST = .TRUE.
      LOGICAL           :: DO_WRITE
      INTEGER           :: I, J, L, N, JLOOP
      REAL*8            :: P_Ox, L_Ox
      CHARACTER(LEN=16) :: STAMP 

      !=================================================================
      ! DIAG20 begins here!
      !=================================================================

      ! Error check
      IF ( IDTOX == 0 ) THEN 
         CALL ERROR_STOP( 'IDTOX = 0!', 'DIAG20 ("diag20_mod.f")' )
      ENDIF

      ! First-time initialization
      IF ( FIRST ) THEN

         ! Starting time of run
         TAUb     = GET_TAUb()

         ! Get time of run at 1st timestep
         TAU0     = TAUb

         ! Reset first-time flag
         FIRST    = .FALSE.

      ENDIF

      !=================================================================
      ! Archive P(Ox) and L(Ox) over the course of an entire day
      !=================================================================

      ! Echo info
      STAMP = TIMESTAMP_STRING()
      WRITE( 6, 120 ) STAMP
 120  FORMAT( '     - DIAG20: Archiving P(Ox) & L(Ox) at ', a )


!$OMP PARALLEL DO
!$OMP+DEFAULT( SHARED )
!$OMP+PRIVATE( I, J, L, P_Ox, L_Ox, JLOOP )
      DO L = 1, LD65
      DO J = 1, JJPAR
      DO I = 1, IIPAR

         !-------------
         ! Counter
         !-------------

         ! JLOOP is the 1-D grid box index for SMVGEAR arrays
         JLOOP = JLOP(I,J,L)

         ! If this is a valid grid box, increment counter
         IF ( JLOOP > 0 ) COUNT(I,J,L) = COUNT(I,J,L) + 1

         !-------------
         ! Production
         !-------------

         ! Convert P(Ox) from [molec/cm3/s] to [kg/cm3/s]
         P_Ox           = FAM_PL(I,J,L,1) / XNUMOL(IDTOX)

         ! Store P(Ox) [kg/cm3/s] in PL24H array
         PL24H(I,J,L,1) = PL24H(I,J,L,1) + P_Ox

         !-------------
         ! Loss
         !-------------

         ! Convert Ox mass from [kg] to [molec]
         L_Ox           = STT(I,J,L,IDTOX) * XNUMOL(IDTOX)

         ! Divide L(Ox) [molec/cm3/s] by Ox mass [molec] 
         ! in order to get L(Ox) in [1/cm3/s]
         L_Ox           = FAM_PL(I,J,L,2) / L_Ox

         ! Store L(Ox) [1/cm3/s] in PL24H array
         PL24H(I,J,L,2) = PL24H(I,J,L,2) + L_Ox
            
      ENDDO
      ENDDO
      ENDDO
!$OMP END PARALLEL DO

      !=================================================================
      ! Write data to disk and zero counters for next timestep
      !=================================================================

      ! Check to see if the next chemistry timestep is the start of a
      ! new day.  If so then we need to write to disk. (bmy, 3/3/05)
      IF ( ITS_TIME_FOR_WRITE20( TAU1 ) ) THEN

         ! Compute average daily values
!$OMP PARALLEL DO
!$OMP+DEFAULT( SHARED )
!$OMP+PRIVATE( I, J, L, N )
         DO N = 1, 2
         DO L = 1, LD65
         DO J = 1, JJPAR
         DO I = 1, IIPAR
            IF ( COUNT(I,J,L) /= 0 )
     $           PL24H(I,J,L,N) = PL24H(I,J,L,N) / COUNT(I,J,L)
         ENDDO
         ENDDO
         ENDDO
         ENDDO
!$OMP END PARALLEL DO

         ! Get YYYYMMDD date for this day
         YYYYMMDD = GET_NYMD()        

         ! Replace YYYYMMDD in filename w/ the actual date
         FILENAME = 'rate.YYYYMMDD'
         CALL EXPAND_DATE( FILENAME, YYYYMMDD, 000000 )

         ! Then prefix FILENAME w/ the data directory name
         FILENAME = TRIM( O3PL_DIR ) // FILENAME

         ! Echo info
         WRITE( 6, 110 ) TRIM( FILENAME )
 110     FORMAT( '     - DIAG20: Writing ', a )

         ! Write P(Ox) and L(Ox) to disk
         CALL WRITE20

         ! Zero arrays
         COUNT = 0
         PL24H = 0d0

         ! Reset for the next day
         TAU0  = TAU1
      ENDIF

      END SUBROUTINE DIAG20
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: write20
!
! !DESCRIPTION: Subroutine WRITE20 saves production and loss rates to disk, 
!  where they will be later read by subroutine CHEMO3. 
!\\
!\\
! !INTERFACE:
!
      SUBROUTINE WRITE20
!
! !USES:
!
      USE BPCH2_MOD,  ONLY : BPCH2,         GET_HALFPOLAR
      USE BPCH2_MOD,  ONLY : GET_MODELNAME, OPEN_BPCH2_FOR_WRITE
      USE FILE_MOD,   ONLY : IU_ND20
      USE GRID_MOD,   ONLY : GET_XOFFSET,   GET_YOFFSET

#     include "CMN_SIZE"   ! Size parameters
#     include "CMN_DIAG"   ! LD65
! 
! !REVISION HISTORY:
!  09 Jun 1999 - I. Bey      - Initial version
!  (1 ) Now bundled into "diag20_mod.f" (bmy, 7/20/04)
!  (2 ) Bug fix: remove declaration of FILENAME which masked the global
!        declaration (bmy, 11/15/04)
!  (3 ) Now make sure all USE statements are USE, ONLY (bmy, 10/3/05)
!  (4 ) Now only write up to LD65 levels (phs, bmy, 12/4/07)
!  15 Sep 2010 - R. Yantosca - Added ProTeX headers 
!EOP
!------------------------------------------------------------------------------
!BOC
!
! !LOCAL VARIABLES:
!
      INTEGER             :: I, J, L, N, IOS
      INTEGER             :: IFIRST, JFIRST, LFIRST
      INTEGER             :: HALFPOLAR 
      INTEGER, PARAMETER  :: CENTER180 = 1 
      REAL*4              :: LONRES, LATRES
      REAL*4              :: ARRAY(IIPAR,JJPAR,LLTROP)
      CHARACTER(LEN=20)   :: MODELNAME
      CHARACTER(LEN=40)   :: CATEGORY
      CHARACTER(LEN=40)   :: UNIT
      CHARACTER(LEN=40)   :: RESERVED
      CHARACTER(LEN=80)   :: TITLE

      !=================================================================
      ! WRITE20 begins here!
      !=================================================================

      ! Define various parameters for the BPCH file
      TITLE     = 'GEOS-CHEM archived P(O3) and L(O3) rates for Tag Ox'
      CATEGORY  = 'PORL-L=$'
      RESERVED  = ''
      LONRES    = DISIZE
      LATRES    = DJSIZE
      MODELNAME = GET_MODELNAME()
      HALFPOLAR = GET_HALFPOLAR()
      IFIRST    = 1 + GET_XOFFSET( GLOBAL=.TRUE. )
      JFIRST    = 1 + GET_YOFFSET( GLOBAL=.TRUE. )
      LFIRST    = 1

      ! Open BPCH file for writing
      CALL OPEN_BPCH2_FOR_WRITE( IU_ND20, FILENAME, TITLE )

      !=================================================================
      ! Save P(O3) to disk
      !=================================================================

      ! Cast to REAL*4 
!$OMP PARALLEL DO
!$OMP+DEFAULT( SHARED )
!$OMP+PRIVATE( I, J, L )
      DO L = 1, LD65
      DO J = 1, JJPAR
      DO I = 1, IIPAR
         ARRAY(I,J,L) = PL24H(I,J,L,1)
      ENDDO
      ENDDO
      ENDDO
!$OMP END PARALLEL DO

      ! Unit string
      UNIT = 'kg/cm3/s'

      ! Save P(O3) to BPCH file
      CALL BPCH2( IU_ND20,   MODELNAME, LONRES,    LATRES,    
     &            HALFPOLAR, CENTER180, CATEGORY,  1,           
     &            UNIT,      TAU0,      TAU1,      RESERVED,  
     &            IIPAR,     JJPAR,     LD65 ,     IFIRST,
     &            JFIRST,    LFIRST,    ARRAY(:,:,1:LD65)  )

      !=================================================================
      ! Save L(O3) to disk
      !=================================================================

      ! Cast to REAL*4 
!$OMP PARALLEL DO
!$OMP+DEFAULT( SHARED )
!$OMP+PRIVATE( I, J, L )
      DO L = 1, LD65
      DO J = 1, JJPAR
      DO I = 1, IIPAR
         ARRAY(I,J,L) = PL24H(I,J,L,2)
      ENDDO
      ENDDO
      ENDDO
!$OMP END PARALLEL DO

      ! Unit string
      UNIT = '1/cm3/s'

      ! Save L(O3) to BPCH file
      CALL BPCH2( IU_ND20,   MODELNAME, LONRES,    LATRES,    
     &            HALFPOLAR, CENTER180, CATEGORY,  2,           
     &            UNIT,      TAU0,      TAU1,      RESERVED,  
     &            IIPAR,     JJPAR,     LD65,      IFIRST,
     &            JFIRST,    LFIRST,    ARRAY(:,:,1:LD65)  )

      ! Close BPCH file
      CLOSE( IU_ND20 )

      END SUBROUTINE WRITE20
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: its_time_for_write20
!
! !DESCRIPTION: Function ITS\_TIME\_FOR\_WRITE20 returns TRUE if it's time to 
!  write the ND20 ozone P/L rate file to disk.  We test the time at the next 
!  chemistry timestep so that we can write to disk properly. 
!\\
!\\
! !INTERFACE:
!
      FUNCTION ITS_TIME_FOR_WRITE20( TAU_W ) RESULT( ITS_TIME )
!
! !USES:
!
      USE TIME_MOD, ONLY : GET_HOUR, GET_MINUTE, GET_TAU
      USE TIME_MOD, ONLY : GET_TAUb, GET_TAUe,   GET_TS_CHEM, GET_TS_DYN
!
! !INPUT PARAMETERS: 
!
      REAL*8,  INTENT(OUT) :: TAU_W      ! TAU value @ time of writing to disk
!
! !RETURN VALUE:
!
      LOGICAL              :: ITS_TIME   ! =T if its time to write to disk
!
! !REVISION HISTORY:
!  20 Jul 2004 - R. Yantosca - Initial version
!  15 Sep 2010 - R. Yantosca - Added ProTeX headers 
!EOP
!------------------------------------------------------------------------------
!BOC
!
! !LOCAL VARIABLES:
!
      REAL*8 :: TAU, HOUR, CHEM, DYN

      !=================================================================
      ! ITS_TIME_FOR_WRITE20 begins here!
      !=================================================================

      ! Initialize
      ITS_TIME = .FALSE.

      ! Current TAU, Hour, and Dynamic Timestep [hrs]
      TAU      = GET_TAU()
      HOUR     = ( GET_MINUTE()  / 60d0 ) + GET_HOUR()
      CHEM     = ( GET_TS_CHEM() / 60d0 )
      DYN      = ( GET_TS_DYN()  / 60d0 )

      ! If first timestep, return FALSE
      IF ( TAU == GET_TAUb() ) RETURN

      ! If the next chemistry timestep is the hour of day
      ! when we have to save to disk, return TRUE
      IF ( MOD( HOUR + CHEM, 24d0 ) == 0 ) THEN
         ITS_TIME = .TRUE.
         TAU_W    = TAU + CHEM
         RETURN
      ENDIF

      ! If the next dyn timestep is the 
      ! end of the run, return TRUE
      IF ( TAU + DYN == GET_TAUe() ) THEN
         ITS_TIME = .TRUE.
         TAU_W    = TAU + DYN
         RETURN
      ENDIF

      END FUNCTION ITS_TIME_FOR_WRITE20
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: get_nfam
!
! !DESCRIPTION: Function GET\_NFAM returns the number of defined P/L families. 
!\\
!\\
! !INTERFACE:
!
      FUNCTION GET_NFAM() RESULT( N_FAM )
!
! !RETURN VALUE:
!
      INTEGER :: N_FAM    ! Number of defined P/L families
!
! !REVISION HISTORY:
!  02 May 2005 - R. Yantosca - Initial version
!  15 Sep 2010 - R. Yantosca - Added ProTeX headers 
!EOP
!------------------------------------------------------------------------------
!BOC
      !=================================================================
      ! GET_N_FAM begins here!
      !=================================================================
      N_FAM = NFAM
    
      END FUNCTION GET_NFAM
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: get_fam_name
!
! !DESCRIPTION: Function GET\_FAM\_NAME returns the name of the 
!  Nth P/L family.
!\\
!\\
! !INTERFACE:
!
      FUNCTION GET_FAM_NAME( N ) RESULT( NAME )
!
! !USES:
!
      USE ERROR_MOD, ONLY : ERROR_STOP
!
! !INPUT PARAMETERS: 
!
      INTEGER, INTENT(IN)  :: N      ! Family # for desired molecular weight
!
! !RETURN VALUE:
!
      CHARACTER(LEN=255)   :: NAME   ! Name of Nth P/L family
!
! !REVISION HISTORY:
!  02 May 2005 - R. Yantosca - Initial version
!  15 Sep 2010 - R. Yantosca - Added ProTeX headers 
!EOP
!------------------------------------------------------------------------------
!BOC
!
! !LOCAL VARIABLES:
!
      CHARACTER(LEN=255) :: MSG

      !=================================================================
      ! GET_FAM_NAME begins here!
      !=================================================================

      ! Error check
      IF ( N < 1 .or. N > NFAM ) THEN
         MSG = 'Invalid ND65 family number!'
         CALL ERROR_STOP( MSG, 'GET_FAM_NAME ("diag_pl_mod.f")' ) 
      ENDIF

      ! Get name
      NAME = TRIM( FAM_NAME( N ) )
      
      END FUNCTION GET_FAM_NAME
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: get_fam_mwt
!
! !DESCRIPTION: Function GET\_FAM\_MWT returns the molecular weight of the 
!  Nth P/L family.
!\\
!\\
! !INTERFACE:
!
      FUNCTION GET_FAM_MWT( N ) RESULT( MWT )
!
! !USES:
!
      USE CHARPAK_MOD, ONLY : TRANUC
      USE ERROR_MOD,   ONLY : ERROR_STOP
      USE TRACER_MOD,  ONLY : N_TRACERS, TRACER_MW_KG, TRACER_NAME
!
! !INPUT PARAMETERS: 
!
      INTEGER, INTENT(IN)  :: N     ! Family # for desired molecular weight
!
! !RETURN VALUE:
!
      REAL*8               :: MWT   ! Molecular weight
!
! !REVISION HISTORY:
!  02 May 2005 - R. Yantosca - Initial version
!  15 Sep 2010 - R. Yantosca - Added ProTeX headers 
!EOP
!------------------------------------------------------------------------------
!BOC
!
! !LOCAL VARIABLES:
!
      INTEGER            :: T
      CHARACTER(LEN=255) :: MSG, PL_NAME, T_NAME 

      !=================================================================
      ! GET_FAM_NAME begins here!
      !=================================================================

      ! Error check
      IF ( N < 1 .or. N > NFAM ) THEN
         MSG = 'Invalid ND65 family number!'
         CALL ERROR_STOP( MSG, 'GET_FAM_MWT ("diag_pl_mod.f")' ) 
      ENDIF

      ! Initialize the MWT
      MWT     = 0d0

      ! Get name of this P/L family
      PL_NAME = TRIM( FAM_NAME( N ) )
      
      ! Convert to uppercase
      CALL TRANUC( PL_NAME )

      ! Skip the 1st character, which is always P or l
      PL_NAME = PL_NAME( 2:LEN_TRIM( PL_NAME ) )

      !=================================================================
      ! Match the name of the P/L family with the GEOS-CHEM tracer name
      ! so that we can find the molecular weight.  This scheme assumes
      ! that each P/L family is a transported tracer.  This may not
      ! always be true but this is a quick & dirty assumption.
      !=================================================================

      ! Loop over all CTM tracers
      DO T = 1, N_TRACERS

         ! Tracer name
         T_NAME = TRACER_NAME( T )

         ! Convert to uppercase
         CALL TRANUC( T_NAME )
         
         ! If we have a name match, return the molecular wt
         IF ( TRIM( PL_NAME ) == TRIM( T_NAME ) ) THEN
            MWT = TRACER_MW_KG( T )
            EXIT
         ENDIF
      ENDDO

      END FUNCTION GET_FAM_MWT
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: init_diag_pl 
!
! !DESCRIPTION: Subroutine INIT\_DIAG\_PL takes values read from the GEOS-Chem
!  input file and saves to module variables w/in "diag65_mod.f" 
!\\
!\\
! !INTERFACE:
!
      SUBROUTINE INIT_DIAG_PL( DOPL, SAVEO3, N_FAM, NAME, 
     &                         TYPE, NMEM,   MEMB,  COEF )
!
! !USES:
!
      USE ERROR_MOD,  ONLY : ALLOC_ERR
      USE TRACER_MOD, ONLY : ITS_A_FULLCHEM_SIM

#     include "CMN_SIZE"   ! Size parameters
#     include "CMN_DIAG"   ! ND65,    LD65
#     include "comode.h"   ! LFAMILY, NFAMILIES
!
! !INPUT PARAMETERS: 
!
      ! Turn on P/L diagnostic?
      LOGICAL,           INTENT(IN) :: DOPL

      ! Save out P(Ox), L(Ox) for future tagged Ox simulation?
      LOGICAL,           INTENT(IN) :: SAVEO3

      ! Number of prod/loss families
      INTEGER,           INTENT(IN) :: N_FAM

      ! Number of members w/in the prod/loss family
      INTEGER,           INTENT(IN) :: NMEM(MAXFAM)

      ! Coefficients for each prod/loss family member
      REAL*8,            INTENT(IN) :: COEF(MAXMEM,MAXFAM)

      ! Prod/loss family name
      CHARACTER(LEN=14), INTENT(IN) :: NAME(MAXFAM)

      ! Prod/loss family type
      CHARACTER(LEN=14), INTENT(IN) :: TYPE(MAXFAM)

      ! Names for each prod/loss family member
      CHARACTER(LEN=14), INTENT(IN) :: MEMB(MAXMEM,MAXFAM)
! 
! !REVISION HISTORY:
!  20 Jul 2004 - R. Yantosca - Initial version
!  (1 ) Now allocate arrays up to LD65 levels (phs, bmy, 12/4/07)
!  15 Sep 2010 - R. Yantosca - Added ProTeX headers 
!EOP
!------------------------------------------------------------------------------
!BOC
!
! !LOCAL VARIABLES:
!
      INTEGER :: AS
 
      !=================================================================
      ! INIT_DIAG_PL begins here!
      !=================================================================

      ! Turn on prod loss diagnostic?
      DO_SAVE_PL = DOPL

      ! Save out P(Ox), L(Ox) for future tagged Ox simulation?
      DO_SAVE_O3 = SAVEO3

      ! Number of prod/loss families
      NFAM       = N_FAM

      ! Define NFAMILIES from "comode.h" for backwards compatibility
      NFAMILIES  = NFAM

      ! Define LFAMILY from "comode.h" for backwards compatibility
      LFAMILY    = ( DO_SAVE_PL .and. NFAM > 0 )

      ! Return if there are no prod/loss families
      ! or if we have turned off this diagnostic
      IF ( .not. LFAMILY ) THEN
         DO_SAVE_PL = .FALSE.
         DO_SAVE_O3 = .FALSE.
         NFAMILIES  = 0
         NFAM       = 0
         ND65       = 0
         RETURN
      ENDIF

      ! Define number of vertical levels to save
      IF ( ITS_A_FULLCHEM_SIM() ) THEN
         LD65 = MIN( ND65, LLTROP )
      ELSE
         LD65 = MIN( ND65, LLPAR  )
      ENDIF

      !=================================================================
      ! Allocate arrays
      !=================================================================
      ALLOCATE( AD65( IIPAR, JJPAR, LD65, NFAM ), STAT=AS )
      IF ( AS /= 0 ) CALL ALLOC_ERR( 'AD65' )

      ALLOCATE( FAM_NMEM( MAXFAM ), STAT=AS )
      IF ( AS /= 0 ) CALL ALLOC_ERR( 'FAM_NMEM' )
      FAM_NMEM = 0

      ALLOCATE( FAM_COEF( MAXMEM, MAXFAM ), STAT=AS )
      IF ( AS /= 0 ) CALL ALLOC_ERR( 'FAM_COEF' )
      FAM_COEF = 0d0

      ALLOCATE( FAM_NAME( MAXFAM ), STAT=AS )
      IF ( AS /= 0 ) CALL ALLOC_ERR( 'FAM_NAME' )
      FAM_NAME = ''

      ALLOCATE( FAM_TYPE( MAXFAM ), STAT=AS )
      IF ( AS /= 0 ) CALL ALLOC_ERR( 'FAM_TYPE' )
      FAM_TYPE = ''

      ALLOCATE( FAM_MEMB( MAXMEM, MAXFAM ), STAT=AS )
      IF ( AS /= 0 ) CALL ALLOC_ERR( 'FAM_COEF' )
      FAM_MEMB = ''

      ALLOCATE( COUNT( IIPAR, JJPAR, LD65 ), STAT=AS )
      IF ( AS /= 0 ) CALL ALLOC_ERR( 'COUNT' )
      COUNT = 0

      ! Only allocate FAM_PL for a fullchem simulation
      IF ( ITS_A_FULLCHEM_SIM() ) THEN
         ALLOCATE( FAM_PL( IIPAR, JJPAR, LD65, NFAM ), STAT=AS )
         IF ( AS /= 0 ) CALL ALLOC_ERR( 'FAM_PL' )
      ENDIF

      ! Allocate PL24H if we are also saving out the P(Ox)
      ! and L(Ox) 
      IF ( DO_SAVE_O3 ) THEN
         ALLOCATE( PL24H( IIPAR, JJPAR, LD65, 2 ), STAT=AS )
         IF ( AS /= 0 ) CALL ALLOC_ERR( 'PL24H' )
         PL24H = 0d0
      ENDIF

      !=================================================================
      ! Assign values from read from GEOS-CHEM input file
      !=================================================================
      FAM_NMEM(:)   = NMEM(:)
      FAM_COEF(:,:) = COEF(:,:)
      FAM_NAME(:)   = NAME(:)
      FAM_TYPE(:)   = TYPE(:)
      FAM_MEMB(:,:) = MEMB(:,:)      
          
      END SUBROUTINE INIT_DIAG_PL
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE: cleanup_diag_pl
!
! !DESCRIPTION: Subroutine CLEANUP\_DIAG\_PL deallocates all module arrays. 
!\\
!\\
! !INTERFACE:
!
      SUBROUTINE CLEANUP_DIAG_PL
! 
! !REVISION HISTORY: 
!  20 Jul 2004 - R. Yantosca - Initial version
!  15 Sep 2010 - R. Yantosca - Added ProTeX headers
!EOP
!------------------------------------------------------------------------------
!BOC
      !=================================================================
      ! CLEANUP_DIAG65 begins here!
      !=================================================================
      IF ( ALLOCATED( AD65     ) ) DEALLOCATE( AD65     )
      IF ( ALLOCATED( FAM_COEF ) ) DEALLOCATE( FAM_COEF )
      IF ( ALLOCATED( FAM_NAME ) ) DEALLOCATE( FAM_NAME )
      IF ( ALLOCATED( FAM_NMEM ) ) DEALLOCATE( FAM_NMEM )
      IF ( ALLOCATED( FAM_MEMB ) ) DEALLOCATE( FAM_MEMB )
      IF ( ALLOCATED( FAM_PL   ) ) DEALLOCATE( FAM_PL   )
      IF ( ALLOCATED( FAM_TYPE ) ) DEALLOCATE( FAM_TYPE )

      END SUBROUTINE CLEANUP_DIAG_PL
!EOC
      END MODULE DIAG_PL_MOD
