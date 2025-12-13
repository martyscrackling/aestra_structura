import 'package:flutter/material.dart';

class ActiveProject extends StatelessWidget {
  const ActiveProject({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // TODO: navigate to project details (backend will replace this)
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => Placeholder()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Super Highway",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2E3A44),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Divisoria, Zamboanga City",
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  "65%",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color.fromARGB(255, 243, 146, 1),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 150,
                  child: LinearProgressIndicator(
                    value: 0.65,
                    backgroundColor: Colors.grey,
                    color: Color.fromARGB(255, 243, 146, 1),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
