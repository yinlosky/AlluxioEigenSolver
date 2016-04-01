function ParallelstoreDataToTFS(NumOfMachines,NumOfProcessors)
%%## This function is used as a helper function to actually call the function to store data into TFS
%%## Author: Yin Huang

myDB;

machines_t = DB('NumOfMachines');
put(machines_t, Assoc('1,','1,',sprintf('%d,', NumOfMachines)));

switch NumOfMachines
        case 1
                machines = {};
        case 2
                machines={'n117' 'n118'};
	case 3
                machines = {'n117' 'n118' 'n119' }
	case 4
                machines = {'n117' 'n118' 'n119' 'n120'  }        
	case 5
                machines = {'n117' 'n118' 'n119' 'n120'  'n121' }  	
	case 6
                machines = {'n117' 'n118' 'n119' 'n120'  'n121'  'n122' }
	case 7
                machines = {'n117' 'n118' 'n119' 'n120'  'n121'  'n122'  'n123'}
	case 8
                machines = {'n117' 'n118' 'n119' 'n120'  'n121'  'n122'  'n123'  'n124'}
	case 9
                machines = {'n117' 'n118' 'n119' 'n120'  'n121'  'n122'  'n123'  'n124'  'n125' }
	case 10
                machines = {'n117' 'n118' 'n119' 'n120'  'n121'  'n122'  'n123'  'n124'  'n125'  'n126' }
	case 11
                machines = {'n117' 'n118' 'n119' 'n120'  'n121'  'n122'  'n123'  'n124'  'n125'  'n126'  'n127' }
	case 12
                machines = {'n117' 'n118' 'n119' 'n120'  'n121'  'n122'  'n123'  'n124'  'n125'  'n126'  'n127'  'n128' }
	case 13
                machines = {'n117' 'n118' 'n119' 'n120'  'n121'  'n122'  'n123'  'n124'  'n125'  'n126'  'n127'  'n128'  'n129'  }
	case 14
                machines = {'n117' 'n118' 'n119' 'n120'  'n121'  'n122'  'n123'  'n124'  'n125'  'n126'  'n127'  'n128'  'n129'  'n130'}
	case 15
		machines = {'n117' 'n118' 'n119' 'n120'  'n121'  'n122'  'n123'  'n124'  'n125'  'n126'  'n127'  'n128'  'n129'  'n130'  'n131'}
	case 16
		machines = {'n117' 'n118' 'n119' 'n120'  'n121'  'n122'  'n123'  'n124'  'n125'  'n126'  'n127'  'n128'  'n129'  'n130'  'n131'  'n132' }
end

  eval(pRUN('storeDataToTFS',NumOfProcessors,machines));
 disp(['Done']);
