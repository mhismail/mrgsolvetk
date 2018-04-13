$PROB 1 cmt PK Model

$PARAM
CL=10
VC = 20
VP = 20
Q=20
Emax = 60
BL = 50
EC50 = 10
gamma =1
sigma1 = 0.1
sigma2 = 0.1

$CMT X1 X2 


$ODE
dxdt_X1 = -(Q+CL)/VC*X1+Q/VP*X2;
dxdt_X2 = Q/VC*X1-Q/VP*X2;


$TABLE
double Y1 = X1/VC;
double varY1 = (Y1*sigma1)*(Y1*sigma1);


double Y2 = BL-(pow(Y1,gamma)*Emax)/(pow(Y1,gamma)+pow(EC50,gamma));
double varY2 = (Y2*sigma2)*(Y2*sigma2);




$CAPTURE Y1 varY1 Y2 varY2