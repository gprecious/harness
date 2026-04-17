export class Service {
  public run(): void {
    console.log("running");
  }

  private unusedHelper(): void {  // never called
    console.log("unused");
  }
}
