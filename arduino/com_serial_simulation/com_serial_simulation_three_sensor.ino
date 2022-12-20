#define START_RANGE 350
#define END_RANGE 399

void simulateAcuityThreeSensorOutput(int start, int end);

void setup()
{
  Serial.begin(9600);
}

void loop() 
{
  simulateAcuityThreeSensorOutput(START_RANGE, END_RANGE);
}

void simulateAcuityThreeSensorOutput(int start, int end)
{
  float randomNumber_1, randomNumber_2, randomNumber_3;

  randomNumber_1 = random(start, end) / 1000.0;
  randomNumber_2 = random(start, end) / 1000.0;
  randomNumber_3 = random(start, end) / 1000.0;

  Serial.print(randomNumber_1, 3);
  Serial.print("\t");
  Serial.print(randomNumber_2, 3);
  Serial.print("\t");
  Serial.println(randomNumber_3, 3);
  delay(1000);
}